defmodule Mx.Examples.BongosTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/bongos.exs"

  test "the solo plays only the bongos" do
    for pass <- 0..20 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ["high_bongo", "low_bongo"]
    end

    refute print(0) =~ "sample "
  end

  test "the martillo plays the macho on every eighth but the seventh, which is the hembra's open tone" do
    martillo = print(0)
    assert beats(martillo, "high_bongo") == [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.5]
    assert beats(martillo, "low_bongo") == [3.0]

    assert martillo =~
             ~r/\nbeat 0 +play muted: 1, vel: 0.8, amp: 1.5\nbeat 0.5 +play muted: 1, vel: 0.4, amp: 1.5\nbeat 1 +play vel: 0.7, amp: 1.5\n/

    assert martillo =~ ~r/low_bongo, pass 0, [^\n]*\nbeat 3 +play vel: 0.85, amp: 1.05\n/
  end

  test "every second bar of the martillo ends on a rim shot, and the heel-tip bars play the fourth and eighth strokes softly" do
    assert print(1) =~ ~r/\nbeat 3.5 +play vel: 1, amp: 1.5\n/

    assert print(2) =~
             ~r/\nbeat 1.5 +play muted: 1, vel: 0.25, amp: 1.5\n.*\nbeat 3.5 +play muted: 1, vel: 0.25, amp: 1.5\n/s
  end

  test "the repiques accent every third sixteenth, play quarter-note triplets across the drums, and the offbeats and the fourth beat" do
    accents =
      for {pass, bar} <- Enum.with_index(6..7),
          [beat] <-
            Regex.scan(~r/^beat (\S+) +play vel: 0.85, amp: 1.5$/m, print(pass),
              capture: :all_but_first
            ),
          do: bar * 4 + number(beat)

    assert accents == Enum.map(0..8, &(&1 * 0.75))

    triplets = print(10)
    assert beats(triplets, "high_bongo") == [0.0, 0.667, 2.0, 2.667]
    assert beats(triplets, "low_bongo") == [1.333, 3.333]

    changui = print(14)
    assert beats(changui, "high_bongo") == [0.5, 1.5, 2.5, 3.5]
    assert beats(changui, "low_bongo") == [3.0]
  end

  test "the ruffs roll three soft strokes into an accent, and the last roll grows into both drums together" do
    assert print(18) =~
             ~r/\nbeat 0.29 +play vel: 0.45, amp: 1.5\nbeat 0.36 +play vel: 0.45, amp: 1.5\nbeat 0.43 +play vel: 0.45, amp: 1.5\nbeat 0.5 +play vel: 0.9, amp: 1.5\n/

    roll = print(19)
    assert beats(roll, "high_bongo") == Enum.map(0..15, &(&1 / 4))

    assert roll =~
             ~r/\nbeat 0 +play vel: 0.45, amp: 1.5\n.*\nbeat 3.75 +play vel: 0.85, amp: 1.5\n/s

    ending = print(20)
    assert ending =~ ~r/high_bongo, pass 20, [^\n]*\nbeat 0 +play vel: 1, amp: 1.5\n/
    assert ending =~ ~r/low_bongo, pass 20, [^\n]*\nbeat 0 +play vel: 0.85, amp: 1.05\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/bongos.exs"
    assert File.read!("LICENSE-designs.md") =~ "bongo recordings"
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

  # The beats one drum's strokes fall on in a printed pass.
  defp beats(printed, drum) do
    [lines] =
      Regex.run(~r/^#{drum}, pass [^\n]*\n((?:beat [^\n]*\n)*)/m, printed,
        capture: :all_but_first
      )

    for [beat] <- Regex.scan(~r/^beat (\S+)/m, lines, capture: :all_but_first),
        do: number(beat)
  end

  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end
end
