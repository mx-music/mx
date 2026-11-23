defmodule Mx.Examples.DrumsTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/drums.exs"
  @kit ~w(closed_hihat crash high_tom kick low_tom mid_tom open_hihat snare)

  test "the solo plays only the drum kit" do
    for pass <- 0..20 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == @kit
    end

    refute print(0) =~ "sample "
  end

  test "the beat is built from the hi-hat alone to the snare's ghost notes and the hi-hat opening for a sixteenth" do
    assert beats(print(0)) == beats(print(0), "closed_hihat")
    assert length(beats(print(0))) == 16

    assert print(1) =~ ~r/snare, pass 1, [^\n]*\nbeat 1 +play vel: 0.89, amp: 0.5\nbeat 3 +play /

    assert print(2) =~
             ~r/snare, pass 2, [^\n]*\nbeat 1 +play vel: 0.89, amp: 0.5\nbeat 1.75 +play vel: 0.22, amp: 0.5\n/

    beat = print(3)
    assert beat =~ ~r/crash, pass 3, [^\n]*\nbeat 0 +play vel: 0.89, amp: 0.5\n/

    assert beat =~
             ~r/open_hihat, pass 3, [^\n]*\nbeat 1.75 +play vel: 0.67, sustain: 0.25, release: 0.05, amp: 0.5\nbeat 3.25 +play /

    assert beats(beat, "kick") == [0.0, 0.5, 2.5, 3.25]
  end

  test "the paradiddle puts the right hand on the hi-hat and the left on the snare" do
    paradiddle = print(6)
    assert beats(paradiddle, "closed_hihat") == [0.0, 0.5, 0.75, 1.25, 2.0, 2.5, 2.75, 3.25]
    assert beats(paradiddle, "snare") == [0.25, 1.0, 1.5, 1.75, 2.25, 3.0, 3.5, 3.75]
  end

  test "the solo accents every third sixteenth for three bars, across the snare and the toms" do
    accents =
      for {pass, bar} <- Enum.with_index(8..10),
          drum <- ~w(snare high_tom mid_tom low_tom),
          {beat, vel} <- strokes(print(pass), drum),
          vel > 0.8,
          do: bar * 4 + beat

    assert Enum.sort(accents) == Enum.map(0..15, &(&1 * 0.75))
  end

  test "it runs down the drums in sextuplets, plays flams and a drag, and rolls from the snare's softest stroke to its hardest" do
    run = print(11)

    for drum <- ~w(snare high_tom mid_tom low_tom) do
      assert length(beats(run, drum)) == 6
    end

    assert print(13) =~ ~r/\nbeat 1.95 +play vel: 0.3, amp: 0.5\nbeat 2 +play vel: 1, amp: 0.5\n/

    assert print(14) =~
             ~r/\nbeat 3.4 +play vel: 0.25, amp: 0.5\nbeat 3.45 +play vel: 0.25, amp: 0.5\nbeat 3.5 +play vel: 1, amp: 0.5\n/

    roll = strokes(print(15), "snare")
    assert length(roll) == 32
    assert hd(roll) == {0.0, 0.11}
    assert List.last(roll) == {3.875, 1.0}
  end

  test "the last crash is choked after three beats" do
    assert print(20) =~
             ~r/crash, pass 20, [^\n]*\nbeat 0 +play vel: 1, sustain: 3, release: 0.1, amp: 0.5\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/drums.exs"
    license = File.read!("LICENSE-designs.md")
    assert license =~ "snare drum recordings"
    assert license =~ "crash cymbal recordings"
    assert license =~ "hi-hat recordings"
    assert license =~ "tom recordings"
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

  defp beats(printed) do
    for [beat] <- Regex.scan(~r/^beat (\S+)/m, printed, capture: :all_but_first),
        do: number(beat)
  end

  defp beats(printed, drum) do
    for {beat, _vel} <- strokes(printed, drum), do: beat
  end

  # One drum's strokes in a printed pass, as {beat, vel}.
  defp strokes(printed, drum) do
    [lines] =
      Regex.run(~r/^#{drum}, pass [^\n]*\n((?:beat [^\n]*\n)*)/m, printed,
        capture: :all_but_first
      )

    for [beat, vel] <-
          Regex.scan(~r/^beat (\S+) +play (?:vel|amp): ([\d.]+)/m, lines, capture: :all_but_first),
        do: {number(beat), number(vel)}
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
