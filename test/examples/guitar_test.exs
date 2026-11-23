defmodule Mx.Examples.GuitarTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @songs ~w(examples/guitar/fingerpicking.exs examples/guitar/bass_line.exs examples/guitar/soft_and_hard.exs)

  test "each guitar example plays the guitar alone" do
    for song <- @songs do
      output = print(song, 0)
      assert output =~ ~r/^\w+, pass 0, /m, song
      assert output =~ ~r/^beat 0 +play /m, song
      refute output =~ "sample ", song
    end
  end

  test "fingerpicking lets each string ring until it is plucked again" do
    output = print("examples/guitar/fingerpicking.exs", 0)
    assert output =~ ~r/^beat 0 +play 45 vel: 0.7, sustain: 3.0/m
    assert output =~ ~r/^beat 0.5 +play 57 vel: 0.5, sustain: 2.0/m
  end

  test "the bass line walks down to the 7-string guitar's low B every eighth bar" do
    assert print("examples/guitar/bass_line.exs", 7) =~ ~r/^beat 3 +play 35 /m
    refute print("examples/guitar/bass_line.exs", 3) =~ ~r/play 35 /
  end

  test "soft and hard plays the same phrase at three strengths" do
    for {pass, vel} <- [{0, "0.3"}, {1, "0.6"}, {2, "1"}] do
      assert print("examples/guitar/soft_and_hard.exs", pass) =~
               ~r/^beat 0 +play 64 vel: #{vel},/m
    end
  end

  test "the examples guide points to the guitar examples" do
    assert File.read!("documentation/examples.md") =~ "examples/guitar"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 400_000
  test "a minute of each guitar example renders without reaching full scale", %{tmp_dir: dir} do
    for song <- @songs do
      out = Path.join(dir, Path.basename(song, ".exs") <> ".wav")
      args = [song, "--render", out, "--seconds", "60"]
      report = capture_io(fn -> Mix.Tasks.Mx.Play.run(args) end)
      assert report =~ "Recorded "

      assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
      assert peak < -0.1, song
    end
  end

  defp print(song, pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([song, "--pass", pass]) end)
  end
end
