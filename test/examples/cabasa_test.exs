defmodule Mx.Examples.CabasaTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/cabasa.exs"

  test "the solo plays only the cabasa" do
    for pass <- 0..11 do
      output = print(pass)
      assert Regex.scan(~r/^(\w+), pass /m, output, capture: :all_but_first) == [["cabasa"]]
    end

    refute print(0) =~ "sample "
  end

  test "it opens on two long turns, the second harder" do
    assert print(0) =~
             ~r/\nbeat 0 +play vel: 0.4, rub: 1, sustain: 3, amp: 0.6\nbeat 4 +play vel: 0.6, rub: 1, sustain: 3, amp: 0.6\n/
  end

  test "the pulse twists the beads on every sixteenth, harder forward than back" do
    pulse = print(1)
    assert length(Regex.scan(~r/^beat .* rub: 1, sustain: 0.1, amp: 0.6$/m, pulse)) == 32

    assert pulse =~
             ~r/\nbeat 0 +play vel: 0.55, rub: 1, sustain: 0.1, amp: 0.6\nbeat 0.25 +play vel: 0.35, rub: 1, sustain: 0.1, amp: 0.6\nbeat 0.5 +play vel: 0.55, /
  end

  test "the bossa nova figure is struck over the pulse, in the twists' place" do
    bossa = print(3)
    assert length(Regex.scan(~r/^beat /m, bossa)) == 32

    struck =
      for [beat] <-
            Regex.scan(~r/^beat (\S+) +play vel: 0.8, amp: 0.6$/m, bossa, capture: :all_but_first),
          do: beat

    assert struck == ~w(0 1.5 3 4.5 6 7)
  end

  test "the figure alone leaves the beads spinning after each stroke, and the ending's turn grows into a stroke" do
    spinning = print(7)
    assert length(Regex.scan(~r/^beat /m, spinning)) == 12

    assert spinning =~
             ~r/\nbeat 1.5 +play vel: 0.8, amp: 0.6\nbeat 1.5 +play vel: 0.45, rub: 1, sustain: 0.5, amp: 0.6\n/

    assert print(11) =~
             ~r/\nbeat 0 +play vel: 0.4, rub: 1, sustain: 2, amp: 0.6\nbeat 2 +play vel: 0.7, rub: 1, sustain: 1.75, amp: 0.6\nbeat 4 +play vel: 0.9, amp: 0.6\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/cabasa.exs"
    assert File.read!("LICENSE-designs.md") =~ "cabasa recordings"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")
    args = [@song, "--render", out, "--seconds", "60"]
    report = capture_io(fn -> Mix.Tasks.Mx.Play.run(args) end)
    assert report =~ "Recorded "

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end
end
