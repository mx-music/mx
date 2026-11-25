defmodule Mx.Examples.ClairDeLuneTest do
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @song "examples/piano/clair_de_lune.exs"

  Code.require_file("../../examples/piano/clair_de_lune_score.exs", __DIR__)

  setup_all do
    {:ok, song} = Mx.Song.load(@song)
    %{song: song}
  end

  test "the piano plays the 72 bars once, and the song ends", %{song: song} do
    assert [%{name: :piano, passes: 1}] = song.loops

    total = 0..71 |> Enum.map(&pass_beats/1) |> Enum.sum() |> Float.round(3)
    assert print() =~ ~r/\Apiano, #{total} beats at 120 bpm/

    for pass <- [0, 40, 71], do: assert(strokes(pass) != [])
    refute print() =~ "sample "
  end

  test "the piece opens on thirds high in D flat and ends on its chord" do
    opening = 0 |> strokes() |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
    assert opening == [65, 68, 73, 77, 80]

    assert Enum.sort(Enum.map(strokes(71), &elem(&1, 0))) ==
             [61, 68, 73, 77, 80, 85, 89, 92]
  end

  test "the right hand's top note sings over the notes under it" do
    {80, top, _} = List.keyfind(strokes(0), 80, 0)
    {77, under, _} = List.keyfind(strokes(0), 77, 0)
    assert top > under
  end

  test "every note is struck with the pedal down, and its dampers fall fast" do
    plays = List.flatten(Regex.scan(~r/play \d+ [^\n]*/, print()))
    assert length(plays) > 1000
    assert Enum.all?(plays, &String.ends_with?(&1, "pedal: 1, release: 0.3"))
  end

  test "the pedal holds the bass of an arpeggio through the bar" do
    {37, _, sustain} = List.keyfind(strokes(28), 37, 0)
    assert sustain > 6
  end

  test "the bars move faster in the Un poco mosso and slow to the end" do
    [opening, mosso, last] = Enum.map([0, 28, 71], &pass_beats/1)
    assert mosso < opening
    assert last > opening
  end

  test "the forte of bar 41 is struck far harder than the opening" do
    loudest = fn pass -> pass |> strokes() |> Enum.map(&elem(&1, 1)) |> Enum.max() end
    assert loudest.(40) > 2 * loudest.(0)
  end

  test "the examples guide points to the performance" do
    assert File.read!("documentation/examples.md") =~ @song
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the performance renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "clair_de_lune.wav")
    args = [@song, "--render", out, "--seconds", "60"]
    report = capture_io(fn -> Mix.Tasks.Mx.Play.run(args) end)
    assert report =~ "Recorded "

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print, do: capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)

  # A pass of the old notation was a bar, so pass n is bar n + 1.
  defp strokes(pass) do
    for {_beat, note, vel, sustain} <- ClairDeLune.strokes(pass + 1), do: {note, vel, sustain}
  end

  defp pass_beats(pass), do: Float.round(ClairDeLune.warp(pass + 1, 9), 3)
end
