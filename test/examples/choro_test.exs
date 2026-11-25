defmodule Mx.Examples.ChoroTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/choro.exs"

  test "the regional plays flute, clarinet, strummed cavaquinho, guitar and pandeiro, and no samples" do
    output = Enum.map_join(0..7, &print/1)

    for loop <-
          ~w(flute clarinet cavaquinho guitar pandeiro_thumb pandeiro_jingles pandeiro_heel pandeiro_slap) do
      assert output =~ ~r/^#{loop}, pass \d+, 32 beats/m
    end

    assert loop_part(print(0), "cavaquinho") =~ ~r/^beat 0.02 +play/m
    refute output =~ "sample "
  end

  test "the form is A A B B A C C A, with B in the relative minor and C in the subdominant" do
    roots =
      for pass <- 0..7 do
        [_, note] = Regex.run(~r/^beat 30 +play (\d+)/m, loop_part(print(pass), "guitar"))
        rem(String.to_integer(note), 12)
      end

    assert roots == [7, 7, 4, 4, 7, 0, 0, 7]
  end

  test "the flute opens on Nazareth's first bar, E D C# D F# E D C, with a mordent on the E" do
    assert Enum.take(notes(loop_part(print(0), "flute")), 10) == [
             76,
             78,
             76,
             74,
             73,
             74,
             78,
             76,
             74,
             72
           ]
  end

  test "a strain plays the same melody each time it comes round, up to its last bar" do
    melody = fn pass -> pass |> print() |> loop_part("flute") |> before(30) end

    assert melody.(4) == melody.(0)
    assert melody.(2) != melody.(0)
  end

  test "the clarinet takes the repeat of A while the flute waits for its pickup, and they play the last A an octave apart" do
    assert before(loop_part(print(1), "flute"), 31) == ""
    assert loop_part(print(0), "clarinet") == ""

    opening = notes(loop_part(print(0), "flute"))
    assert Enum.take(notes(loop_part(print(1), "clarinet")), 100) == Enum.take(opening, 100)

    flute = for note <- notes(before(loop_part(print(7), "flute"), 30)), do: note - 12
    assert notes(before(loop_part(print(7), "clarinet"), 30)) == flute
  end

  test "choro states the key it starts in, G major" do
    {:ok, song} = Mx.Song.load(@song)
    assert song.key == :g
  end

  @tag :tmp_dir
  test "choro writes its score with one sharp without a key given", %{tmp_dir: dir} do
    out = Path.join(dir, "choro.musicxml")
    capture_io(fn -> Mix.Tasks.Mx.Export.run([@song, "--out", out]) end)
    assert File.read!(out) =~ "<key><fifths>1</fifths><mode>major</mode></key>"
  end

  test "the examples guide points to the demo" do
    assert File.read!("documentation/examples.md") =~ "examples/choro.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the demo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "choro.wav")
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

  defp loop_part(output, loop) do
    [part | _] = output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl()
    part |> String.split("\n\n") |> hd()
  end

  # Every pitch a part sounds, in order: the notes it plays and the notes its breaths change to.
  defp notes(part) do
    for [_, note] <- Regex.scan(~r/(?:play|control note:) (\d+)/, part),
        do: String.to_integer(note)
  end

  # A part's lines before a beat.
  defp before(part, beat) do
    part
    |> String.split("\n", trim: true)
    |> Enum.filter(fn line ->
      [_, at] = Regex.run(~r/^beat ([\d.]+)/, line)
      elem(Float.parse(at), 0) < beat
    end)
    |> Enum.join("\n")
  end
end
