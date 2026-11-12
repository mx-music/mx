defmodule Mx.Examples.TranquilityBaseTest do
  # The piece renders, and the GitHub cache and server are the application's settings.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/tranquility_base.exs"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"

  test "the piece names no absolute path, and NASA's five recordings ship beside it" do
    source = File.read!(@song)
    refute source =~ ~r/"\//
    refute source =~ "~/"

    for file <- ~w(a11landing.aiff a11step.aiff a11liftoff.aiff sputnik.wav apollo_13_problem.wav),
        do: assert(File.exists?(Path.join("examples/tranquility_base", file)))
  end

  test "the licence notes name VCSL and NASA's recordings with their source, and the README lists the piece" do
    notes = File.read!("LICENSE-designs.md")

    assert notes =~
             "examples/tranquility_base.exs plays recordings of Versilian Studios' Versilian Community Sample Library, https://github.com/sgossner/VCSL, under CC0"

    assert notes =~
             "courtesy of NASA, from https://nssdc.gsfc.nasa.gov/planetary/sound/index.html"

    readme = File.read!("README.md")
    assert readme =~ "mx examples/tranquility_base.exs"
    assert readme =~ ~s(mx samples download "sgossner/VCSL@#{@commit}:Idiophones")
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
          if previous,
            do: Application.put_env(:mx, key, previous),
            else: Application.delete_env(:mx, key)
        end)
      end

      :ok
    end

    test "it plays only samples from the cache with the network cut, and mix mx.print shows them" do
      {output, errors} = print()
      assert errors == ""
      refute output =~ ~r/^beat \S+\s+play/m
      assert output =~ ~r/^kushaura, 128 beats at 136 bpm/m

      kushaura = part(output, "kushaura")

      assert kushaura =~
               "beat 0        sample sgossner/VCSL Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B/MBira4_pluck_Main_B2_13_50_100_rr3.wav"

      # The lead's D#5 is above the mbira's highest key, so it plays from C#5 two semitones faster.
      assert kushaura =~
               "MBira4_pluck_Main_C#5_24_50_100_rr5.wav amp: 1.5, pan: -0.3, sustain: 3, release: 1, rate: 1.122462048309373"

      hats = for [_, take] <- Regex.scan(~r/HiHat_HitC_v4_(rr\d)/, part(output, "hat")), do: take
      assert Enum.take(hats, 4) == ~w(rr1 rr2 rr1 rr2)

      assert part(output, "voice") =~
               "apollo_13_problem.wav from: 0.0, to: 1.6, slices: 4, slice: 0, beats: 1"

      assert part(output, "sputnik") =~
               "sputnik.wav from: 0.0, to: 0.4366, beats: 1, amp: 0.25, rate: 0.9896"
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
      assert Mx.Recording.seconds(out) > 55
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
