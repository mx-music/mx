defmodule Mx.Examples.TranquilityBaseTest do
  # The piece renders, and the GitHub cache and server are the application's settings.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/tranquility_base.exs"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"

  test "the piece names no absolute path, and NASA's seven recordings ship beside it" do
    source = File.read!(@song)
    refute source =~ ~r/"\//
    refute source =~ "~/"

    for file <-
          ~w(a11kennedy.aiff a11liftoff.aiff a11landing.aiff a11step.aiff a11magnif.aiff sputnik.wav apollo_13_problem.wav),
        do: assert(File.exists?(Path.join("examples/tranquility_base", file)))
  end

  test "the licence notes name VCSL and NASA's recordings with their source, and the examples guide lists the piece" do
    notes = File.read!("LICENSE-designs.md")

    assert notes =~
             "examples/tranquility_base.exs plays recordings of Versilian Studios' Versilian Community Sample Library, https://github.com/sgossner/VCSL, under CC0"

    assert notes =~
             "courtesy of NASA, from https://nssdc.gsfc.nasa.gov/planetary/sound/index.html"

    guide = File.read!("documentation/examples.md")
    assert guide =~ "mx examples/tranquility_base.exs"
    assert guide =~ ~s(mx samples download "sgossner/VCSL@#{@commit}:Idiophones")
  end

  # Versilian Studios' Versilian Community Sample Library at the commit the piece names, in the folder MX_VCSL names, standing in for the GitHub cache, with the network cut.
  describe "with VCSL" do
    @describetag :vcsl
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      vcsl = System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")
      repo = Path.join(dir, "sgossner/VCSL")
      File.mkdir_p!(repo)
      File.ln_s!(vcsl, Path.join(repo, @commit))

      for {key, value} <- [
            github_dir: dir,
            github_raw_url: "http://127.0.0.1:1",
            github_api_url: "http://127.0.0.1:1"
          ] do
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

      :ok
    end

    test "it plays only samples from the cache with the network cut, and mix mx.print shows them" do
      {output, errors} = print()
      assert errors == ""
      refute output =~ ~r/^beat \S+\s+play/m
      assert output =~ ~r/^hat, 248 beats at 136 bpm/m

      assert part(output, "kick") =~
               "beat 48   sample sgossner/VCSL Membranophones/Struck Membranophones/Bass Drum 1/BDrumNew_hit_v7_rr1_Sum.wav amp: 0.54"

      hats = for [_, take] <- Regex.scan(~r/HiHat_HitC_v3_(rr\d)/, part(output, "hat")), do: take
      assert Enum.take(hats, 4) == ~w(rr1 rr2 rr1 rr2)

      assert part(output, "voice") =~
               "a11landing.aiff from: 2.1, to: 2.4, amp: 0.8, rate: 1.06"

      assert part(output, "sputnik") =~
               "sputnik.wav from: 0.3, to: 2.06, beats: 4, amp: 0.25, rate: 0.9973"
    end

    @tag timeout: 300_000
    test "it renders without reaching full scale, and names no quiet sample or file it cannot read",
         %{tmp_dir: dir} do
      out = Path.join(dir, "tranquility_base.wav")

      errors =
        capture_io(:stderr, fn ->
          capture_io(fn -> assert :ok = Mx.Render.render(@song, out, []) end)
        end)

      assert errors == ""
      assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
      assert peak < -1
      assert Mx.Recording.seconds(out) > 105
    end
  end

  defp print do
    errors =
      capture_io(:stderr, fn ->
        send(self(), {:output, capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)})
      end)

    assert_received {:output, output}
    cache = Application.get_env(:mx, :github_dir)
    {String.replace(output, cache <> "/sgossner/VCSL/#{@commit}/", "sgossner/VCSL "), errors}
  end

  defp part(output, name) do
    [_, part | _] = String.split(output, ~r/^#{name}, [^\n]*\n/m)
    part |> String.split("\n\n") |> hd()
  end
end
