defmodule Mx.Examples.ViolaTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/solo/viola.exs"

  test "the solo plays only the viola" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["viola"]]
    end

    refute print(0) =~ "sample "
  end

  test "the cantabile slurs the melody low on the C string, and swells its long notes" do
    assert print(0) =~
             ~r/\nbeat 0 +play 48 vel: 0.6, sustain: 1.9, release: 0.15, vibrato: 0.08\nbeat 1.5 +control note: 50, note_slide: 0.01\n/

    assert print(0) =~
             ~r/\nbeat 4 +play 53 vel: 0.6, amp: 0.6, sustain: 1.9, release: 0.15, vibrato: 0.08\n/
  end

  test "the tremolo repeats each note in sixteenths, from soft to loud" do
    assert print(1) =~
             ~r/\nbeat 0 +play 60 vel: 0.45, sustain: 0.2, release: 0.05, vibrato: 0\nbeat 0.25 +play 60 vel: 0.35,/

    assert print(1) =~ ~r/\nbeat 14.25 +play 63 vel: 0.84,/
  end

  test "the arpeggios slur four notes to a bow across the strings, without sliding" do
    assert print(2) =~
             ~r/\nbeat 0 +play 48 vel: 0.75, sustain: 0.9, release: 0.15, vibrato: 0\nbeat 0.25 +control note: 55, note_slide: 0.01\n/
  end

  test "the plucked chords pluck their notes and let them ring" do
    assert print(3) =~ ~r/\nbeat 4 +play 53 vel: 0.8, pizz: 1, sustain: 4\n/
  end

  test "the ending settles on the low C, swelled" do
    assert print(4) =~
             ~r/\nbeat 12 +play 48 vel: 0.65, amp: 0.6, sustain: 3.9, release: 0.15, vibrato: 0.08\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/viola.exs"
    assert File.read!("LICENSE-designs.md") =~ "The viola is measured"
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
