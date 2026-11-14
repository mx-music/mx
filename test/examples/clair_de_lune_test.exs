defmodule Mx.Examples.ClairDeLuneTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/piano/clair_de_lune.exs"

  Code.require_file("../../examples/piano/clair_de_lune_score.exs", __DIR__)

  setup_all do
    {:ok, song} = Mx.Song.load(@song)
    %{song: song}
  end

  test "the piano plays the 72 bars once, and the song ends", %{song: song} do
    assert [%{name: :piano, passes: 1}] = song.loops

    total = Enum.map(0..71, &pass_beats/1) |> Enum.sum() |> Float.round(3)
    assert print() =~ ~r/\Apiano, #{total} beats at 120 bpm/

    for pass <- [0, 40, 71], do: assert(strokes(pass) != [])
    refute print() =~ "sample "
  end

  test "the piece opens on thirds high in D flat and ends on its chord" do
    opening = strokes(0) |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
    assert opening == [65, 68, 73, 77, 80]

    assert Enum.map(strokes(71), &elem(&1, 0)) |> Enum.sort() ==
             [61, 68, 73, 77, 80, 85, 89, 92]
  end

  test "the right hand's top note sings over the notes under it" do
    {80, top, _} = List.keyfind(strokes(0), 80, 0)
    {77, under, _} = List.keyfind(strokes(0), 77, 0)
    assert top > under
  end

  test "every note is struck with the pedal down, and its dampers fall fast" do
    plays = Regex.scan(~r/play \d+ [^\n]*/, print()) |> List.flatten()
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
    loudest = fn pass -> strokes(pass) |> Enum.map(&elem(&1, 1)) |> Enum.max() end
    assert loudest.(40) > 2 * loudest.(0)
  end

  test "the examples guide points to the performance" do
    assert File.read!("documentation/examples.md") =~ @song
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the performance records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "clair_de_lune.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out])
    after
      Process.group_leader(self(), leader)
    end

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print, do: capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)

  # A pass of the old notation was a bar, so pass n is bar n + 1.
  defp strokes(pass) do
    for {_beat, note, vel, sustain} <- ClairDeLune.strokes(pass + 1), do: {note, vel, sustain}
  end

  defp pass_beats(pass), do: Float.round(ClairDeLune.warp(pass + 1, 9), 3)

  # An input device that answers the first line asked for after a delay, as a person pressing
  # Enter would.
  defp enter_after(ms) do
    receive do
      {:io_request, from, ref, {:get_line, _, _}} ->
        Process.sleep(ms)
        send(from, {:io_reply, ref, "\n"})
        enter_after(ms)

      {:io_request, from, ref, _request} ->
        send(from, {:io_reply, ref, :ok})
        enter_after(ms)
    end
  end
end
