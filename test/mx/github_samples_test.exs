defmodule Mx.GitHubSamplesTest do
  # The GitHub server and cache are the application's settings, so these tests run one at a time.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.{FakeGitHub, Pass, Samples, Song}

  @moduletag :tmp_dir

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @folder "Idiophones/Struck Idiophones/Agogo Bells"
  @agogo "#{@folder}/Agogo_High_v1_rr1_Mid.wav"
  @low "#{@folder}/Agogo_Low_v1_rr1_Mid.wav"

  setup %{tmp_dir: dir} do
    wav = wav()

    files = %{
      @agogo => wav,
      @low => wav,
      "Membranophones/Bass Drum 1/BDrumNew_hit_v2_rr1_Sum.wav" => wav
    }

    FakeGitHub.start(%{@repo => %{@commit => files, "master" => files}}, dir: dir)
    %{wav: wav}
  end

  # A tenth of a second of a stereo 16-bit WAV at 48 kHz, at a level of 0.5.
  defp wav do
    data = :binary.copy(<<16_384::little-signed-16, 16_384::little-signed-16>>, 4800)
    size = byte_size(data)

    "RIFF" <>
      <<36 + size::little-32>> <>
      "WAVEfmt " <>
      <<16::little-32, 1::little-16, 2::little-16, 48_000::little-32, 192_000::little-32,
        4::little-16, 16::little-16>> <> "data" <> <<size::little-32>> <> data
  end

  defp song(dir, path, ref \\ @commit) do
    file = Path.join(dir, "song.exs")

    File.write!(file, """
    import Mx
    song(music: part(:agogo, sample({:github, #{inspect(@repo)}, #{inspect(ref)}, #{inspect(path)}}, 1)))
    """)

    file
  end

  defp load(file) do
    {result, output} = with_io(fn -> Song.load(file) end)
    {result, output}
  end

  defp cut_network, do: Application.put_env(:mx, :github_raw_url, "http://127.0.0.1:1")

  test "a GitHub sample is downloaded into the cache when the song loads, naming the file, and plays from it",
       %{
         tmp_dir: dir
       } do
    assert {{:ok, song}, output} = load(song(dir, @agogo))
    assert output == "Downloading #{@agogo} from #{@repo} at #{@commit}\n"
    cached = Mx.GitHub.local(@repo, @commit, @agogo)
    assert [loop] = song.loops
    assert loop.samples == [cached]
    assert {:ok, %{events: [{0, {:sample, _, ^cached}, []}]}} = Pass.events(loop, 0)
    refute File.exists?(cached <> ".part")
  end

  test "a GitHub sample in the cache plays with the network cut, and downloads nothing", %{
    tmp_dir: dir
  } do
    assert {{:ok, _}, _} = load(song(dir, @agogo))
    cut_network()
    assert {{:ok, song}, ""} = load(song(dir, @agogo))
    assert hd(song.loops).samples == [Mx.GitHub.local(@repo, @commit, @agogo)]
  end

  test "each ref of a repository has its own folder in the cache", %{tmp_dir: dir} do
    assert {{:ok, _}, _} = load(song(dir, @agogo, "master"))
    assert {{:ok, _}, _} = load(song(dir, @agogo))
    master = Mx.GitHub.local(@repo, "master", @agogo)
    commit = Mx.GitHub.local(@repo, @commit, @agogo)
    assert master != commit
    assert File.exists?(master) and File.exists?(commit)
  end

  test "a file the repository does not have is refused, naming the loop, the repository, the path and the ref",
       %{
         tmp_dir: dir
       } do
    missing = "#{@folder}/Missing.wav"

    assert {{:error, message}, _} = load(song(dir, missing))

    assert message ==
             "loop agogo: cannot download sample #{missing} from #{@repo}: the file is not in #{@repo} at #{@commit}"
  end

  test "with the network cut and nothing in the cache, the song is refused with the reason", %{
    tmp_dir: dir
  } do
    cut_network()
    assert {{:error, message}, _} = load(song(dir, @agogo))

    assert message ==
             "loop agogo: cannot download sample #{@agogo} from #{@repo}: cannot connect to GitHub"
  end

  test "a GitHub sample not written as {:github, owner/repo, ref, path} is refused", %{
    tmp_dir: dir
  } do
    file = Path.join(dir, "song.exs")

    File.write!(
      file,
      "import Mx\nsong(music: part(:a, sample({:github, \"VCSL\", \"master\", \"a.wav\"}, 1)))\n"
    )

    assert {{:error, message}, _} = load(file)

    assert message =~
             ~s(a GitHub sample is {:github, "owner/repo", ref, path}, not {:github, "VCSL", "master", "a.wav"})
  end

  test "mix mx.print names a GitHub sample by its repository and path", %{tmp_dir: dir} do
    file = song(dir, @agogo)
    output = capture_io(fn -> Mix.Tasks.Mx.Print.run([file]) end)
    assert output =~ "beat 0  sample #{@repo} #{@agogo}\n"
  end

  test "a sampled instrument from a GitHub folder downloads it when the song loads, then plays it",
       %{tmp_dir: dir} do
    file = Path.join(dir, "song.exs")

    File.write!(file, """
    import Mx
    song(music: part(:agogo, seq([hit(), rest(1), hit(), rest(1)]), synth: sampled({:github, #{inspect(@repo)}, #{inspect(@commit)}, #{inspect(@folder)}})))
    """)

    assert {{:ok, song}, output} = load(file)

    assert output =~
             ~r/^Downloaded 2 files to .*, and #{@repo}@#{@commit}:#{@folder} is complete\.\n$/

    assert {:ok, %{events: events}} = Pass.events(hd(song.loops), 0)
    played = for {_, {:sample, _, path}, _} <- events, do: Path.basename(path)
    assert played == ["Agogo_High_v1_rr1_Mid.wav", "Agogo_Low_v1_rr1_Mid.wav"]
    assert File.exists?(Mx.GitHub.local(@repo, @commit, @low))

    cut_network()
    Application.put_env(:mx, :github_api_url, "http://127.0.0.1:1")
    assert {{:ok, _}, ""} = load(file)
  end

  test "a sampled instrument lists GitHub files, reading what they do not give from their names",
       %{tmp_dir: dir} do
    file = Path.join(dir, "song.exs")
    drum = "Membranophones/Bass Drum 1/BDrumNew_hit_v2_rr1_Sum.wav"

    File.write!(file, """
    import Mx
    files = [{:github, #{inspect(@repo)}, #{inspect(@commit)}, #{inspect(drum)}}, {{:github, #{inspect(@repo)}, #{inspect(@commit)}, #{inspect(@agogo)}}, strength: 9}]
    song(music: part(:drum, seq([hit(vel: 0), rest(1), hit(vel: 1), rest(1)]), synth: sampled(files)))
    """)

    assert {{:ok, song}, output} = load(file)
    assert output =~ "Downloading #{drum} from #{@repo}"
    assert {:ok, %{events: events}} = Pass.events(hd(song.loops), 0)

    names = for {_, {:sample, _, path}, _} <- events, do: Path.basename(path)

    assert names == [
             "BDrumNew_hit_v2_rr1_Sum.wav",
             "Agogo_High_v1_rr1_Mid.wav"
           ]
  end

  test "a GitHub folder that cannot be downloaded is refused, naming the part", %{tmp_dir: dir} do
    file = Path.join(dir, "song.exs")

    File.write!(
      file,
      "import Mx\nsong(music: part(:x, hit(), synth: sampled({:github, #{inspect(@repo)}, \"no-such-ref\", \"Drums\"})))\n"
    )

    assert {{:error, message}, _} = load(file)

    assert message =~
             "part x: cannot download folder Drums of #{@repo}: #{@repo} has no ref no-such-ref"
  end

  describe "downloading a collection" do
    test "a folder downloads every file into the cache a song plays from, then nothing", %{
      tmp_dir: dir
    } do
      source = "#{@repo}@#{@commit}:#{@folder}"
      folder = Path.dirname(Mx.GitHub.local(@repo, @commit, "file"))

      assert Samples.download_source(source) ==
               {:ok, "Downloaded 2 files to #{folder}, and #{source} is complete."}

      assert File.exists?(Mx.GitHub.local(@repo, @commit, @low))

      refute File.exists?(
               Mx.GitHub.local(
                 @repo,
                 @commit,
                 "Membranophones/Bass Drum 1/BDrumNew_hit_v2_rr1_Sum.wav"
               )
             )

      assert Samples.download_source(source) == {:ok, "#{source} is complete in #{folder}."}

      cut_network()
      assert {{:ok, _}, ""} = load(song(dir, @agogo))
    end

    test "a file that fails is named, the others stay, and a second run downloads only the rest",
         %{
           tmp_dir: dir,
           wav: wav
         } do
      files = %{@agogo => wav, @low => :fail}
      FakeGitHub.start(%{@repo => %{@commit => files}}, dir: Path.join(dir, "again"))
      source = "#{@repo}@#{@commit}"

      assert {:error, message} = Samples.download_source(source)
      assert message =~ "Could not download #{@low}: GitHub answered 500.\n"
      assert message =~ "The 1 files downloaded before it stay in"
      assert message =~ "run mix mx.samples.download #{source} again to finish."
      assert File.exists?(Mx.GitHub.local(@repo, @commit, @agogo))

      FakeGitHub.start(%{@repo => %{@commit => %{files | @low => wav}}},
        dir: Path.join(dir, "again")
      )

      assert {:ok, "Downloaded 1 files to " <> _} = Samples.download_source(source)
    end

    test "a source that is neither a collection nor owner/repo@ref is refused, showing both" do
      assert {:error, message} = Samples.download_source("VCSL")
      assert message =~ ~r/^SOURCE is a collection, one of .*sonic_pi, vcsl, /

      assert message =~
               "or a GitHub repository as owner/repo@ref, optionally followed by :folder, not VCSL"
    end

    test "a ref, repository or folder GitHub does not have is refused before anything downloads" do
      assert Samples.download_source("#{@repo}@no-such-ref") ==
               {:error, "#{@repo} has no ref no-such-ref"}

      assert Samples.download_source("someone/nothing@main") ==
               {:error, "GitHub has no public repository someone/nothing"}

      assert Samples.download_source("#{@repo}@#{@commit}:Aerophones") ==
               {:error, "#{@repo} has no folder Aerophones at #{@commit}"}

      refute File.exists?(Mx.GitHub.dir())
    end

    test "GitHub's limit of requests without a login is named, with when it resets", %{
      tmp_dir: dir
    } do
      FakeGitHub.start(%{@repo => %{"master" => %{}}},
        dir: Path.join(dir, "limited"),
        limited: true
      )

      assert Samples.download_source("#{@repo}@master") ==
               {:error,
                "GitHub's limit of requests without a login is reached; it resets at 2027-01-15 08:00 UTC"}
    end
  end

  describe "Sonic Pi's pack" do
    setup %{tmp_dir: dir} do
      served = Path.join(dir, "served")
      File.mkdir_p!(served)
      for name <- Samples.names() ++ ["README.md"], do: File.write!(Path.join(served, name), name)

      {:ok, server} =
        :inets.start(:httpd,
          port: 0,
          server_name: ~c"mx-test-pack",
          server_root: String.to_charlist(dir),
          document_root: String.to_charlist(served),
          bind_address: {127, 0, 0, 1}
        )

      port = :httpd.info(server)[:port]
      pack = Path.join(dir, "pack")

      for {key, value} <- [samples_dir: pack, samples_url: "http://127.0.0.1:#{port}"] do
        previous = Application.get_env(:mx, key)
        Application.put_env(:mx, key, value)

        on_exit(fn ->
          if previous do
            Application.put_env(:mx, key, previous)
          else
            Application.delete_env(:mx, key)
          end
        end)
      end

      on_exit(fn -> :inets.stop(:httpd, server) end)
      %{pack: pack, port: port}
    end

    test "sonic_pi downloads the pack's 206 samples and its licence, then says the pack is complete",
         %{pack: pack} do
      assert length(Samples.names()) == 206

      assert Samples.download_source("sonic_pi") ==
               {:ok, "Downloaded 207 files to #{pack}, and Sonic Pi's sample pack is complete."}

      assert Samples.download_source("sonic_pi") ==
               {:ok, "Sonic Pi's sample pack is complete in #{pack}."}
    end

    test "a pack downloaded before stays where it is and downloads nothing", %{pack: pack} do
      File.mkdir_p!(pack)
      for name <- Samples.names() ++ ["README.md"], do: File.write!(Path.join(pack, name), name)
      Application.put_env(:mx, :samples_url, "http://127.0.0.1:1")

      assert Samples.download_source("sonic_pi") ==
               {:ok, "Sonic Pi's sample pack is complete in #{pack}."}

      assert Samples.default_dir() =~ "samples-v5.0.0"
    end

    test "mix mx.samples.download sonic_pi does the same, and mix mx.samples is gone", %{
      pack: pack
    } do
      assert capture_io(fn -> Mix.Tasks.Mx.Samples.Download.run(["sonic_pi"]) end) ==
               "Downloaded 207 files to #{pack}, and Sonic Pi's sample pack is complete.\n"

      assert Mix.Task.get("mx.samples") == nil
    end
  end

  test "mx with no arguments shows how to download samples" do
    assert File.read!("bin/mx") =~ "mx samples download SOURCE"
  end

  test "the README shows downloading Sonic Pi's pack, and the notation guide a GitHub sample, a VCSL sample and a VCSL folder ahead of time" do
    assert File.read!("README.md") =~ "mix mx.samples.download sonic_pi"
    guide = File.read!("documentation/notation.md")
    assert guide =~ ~s(sample({:github, "owner/repo")
    assert guide =~ ~s(sample({:vcsl, ")
    assert guide =~ ~s(mix mx.samples.download "vcsl:)
  end
end
