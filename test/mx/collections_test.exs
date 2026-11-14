defmodule Mx.CollectionsTest do
  # The GitHub server and cache are the application's settings, so these tests run one at a time.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Mx

  alias Mx.{Collections, FakeGitHub, Samples, Song}

  @moduletag :tmp_dir

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
  @folder "Idiophones/Struck Idiophones/Agogo Bells"
  @agogo "#{@folder}/Agogo_High_v1_rr1_Mid.wav"
  @low "#{@folder}/Agogo_Low_v1_rr1_Mid.wav"
  @pack "test/support/samples"

  setup %{tmp_dir: dir} do
    files = %{@agogo => wav(), @low => wav()}
    FakeGitHub.start(%{@repo => %{@commit => files}}, dir: dir)
    :ok
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

  defp load(dir, music) do
    file = Path.join(dir, "song.exs")
    File.write!(file, "import Mx\nsong(music: #{music})\n")
    with_io(fn -> Song.load(file) end)
  end

  test "every collection but Sonic Pi's is a GitHub repository pinned to a commit" do
    assert :sonic_pi in Collections.names()
    assert Collections.github(:vcsl) == {@repo, @commit}
    assert Collections.github(:sonic_pi) == nil

    for name <- Collections.names(), name != :sonic_pi do
      assert {repo, commit} = Collections.github(name)
      assert repo =~ ~r"^[\w.-]+/[\w.-]+$"
      assert commit =~ ~r/^[0-9a-f]{40}$/
    end
  end

  test "the notation guide lists every collection" do
    guide = File.read!("documentation/notation.md")

    for name <- Collections.names() do
      name = inspect(name)
      assert guide =~ "`#{name}`"
    end
  end

  test "a sample of Sonic Pi's pack is named with its collection" do
    assert Samples.path({:sonic_pi, :bd_haus}, @pack) == {:ok, Path.expand("bd_haus.flac", @pack)}
    assert Samples.path({:sonic_pi, :bd_hause}, @pack) == {:error, "unknown sample bd_hause"}
  end

  test "a name without its collection is refused, showing how to write it" do
    assert_raise ArgumentError,
                 "sample :bd_haus needs its collection, as {:sonic_pi, :bd_haus}",
                 fn -> sample(:bd_haus, 1) end
  end

  test "a collection mx does not know is refused, naming it" do
    assert_raise ArgumentError, ~r/^mx has no collection nope; its collections are .*vcsl/, fn ->
      sample({:nope, "kick.wav"}, 1)
    end

    assert_raise ArgumentError, ~r/^mx has no collection nope/, fn ->
      sampled({:nope, "Kicks"})
    end
  end

  test "a sample of a collection is downloaded from its repository at its commit when the song loads",
       %{tmp_dir: dir} do
    music = "part(:agogo, sample({:vcsl, #{inspect(@agogo)}}, 1))"
    assert {{:ok, song}, output} = load(dir, music)
    assert output == "Downloading #{@agogo} from #{@repo} at #{@commit}\n"
    assert hd(song.loops).samples == [Mx.GitHub.local(@repo, @commit, @agogo)]
  end

  test "a file the collection does not have is refused, naming the loop, the path and the repository",
       %{
         tmp_dir: dir
       } do
    assert {{:error, message}, _} = load(dir, "part(:agogo, sample({:vcsl, \"Nothing.wav\"}, 1))")
    assert message =~ "loop agogo"
    assert message =~ "cannot download sample Nothing.wav from #{@repo}"
  end

  test "a sampled instrument plays a folder of a collection, and lists files of one", %{
    tmp_dir: dir
  } do
    folder = "part(:agogo, steps(\"x\", 1), synth: sampled({:vcsl, #{inspect(@folder)}}))"
    assert {{:ok, song}, _} = load(dir, folder)
    assert [_ | _] = hd(song.loops).samples

    listed =
      "part(:agogo, note(:c4, 1), synth: sampled([{{:vcsl, #{inspect(@agogo)}}, note: :c4}]))"

    assert {{:ok, song}, _} = load(dir, listed)
    assert hd(song.loops).samples == [Mx.GitHub.local(@repo, @commit, @agogo)]
  end

  describe "download_source/1" do
    test "a collection's name downloads its repository at its commit, and a folder after a colon only that folder" do
      source = "vcsl:#{@folder}"
      assert {:ok, "Downloaded 2 files to " <> _} = Samples.download_source(source)
      assert File.exists?(Mx.GitHub.local(@repo, @commit, @low))
      assert {:ok, message} = Samples.download_source("vcsl")
      assert message =~ "vcsl is complete in"
    end

    test "a source that is no collection and no owner/repo@ref is refused, naming the collections" do
      assert {:error, message} = Samples.download_source("nope")
      assert message =~ "SOURCE is a collection"
      assert message =~ "sonic_pi"
      assert message =~ "vcsl"
      assert message =~ "owner/repo@ref"
      assert message =~ "not nope"
    end
  end
end
