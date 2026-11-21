defmodule Mx.PassTest do
  use ExUnit.Case, async: true

  alias Mx.{Pass, Song}

  @moduletag :tmp_dir

  defp notes(dir, body) do
    path = Path.join(dir, "song.exs")
    File.write!(path, "import Mx\n" <> body)
    {:ok, %{loops: [loop]}} = Song.load(path)
    {:ok, %{notes: notes}} = Pass.events(loop, 0)
    notes
  end

  test "gives each note as written, its length its beats or the sustain it is given", %{
    tmp_dir: dir
  } do
    assert notes(dir, """
           song(music: part(:lead, seq([note(:c4, 1), note(:e4, 2, sustain: 0.5), rest(1), note([:c4, :g4], 1)]), synth: :tri))
           """) == [{0, 60, 1}, {1, 64, 0.5}, {4, 60, 1}, {4, 67, 1}]
  end

  test "a pass refuses a value an option cannot take, naming the part and the option", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "song.exs")

    File.write!(path, """
    import Mx
    song(music: part(:x, loop(3, fn pass, _ -> note(:c4, 1, cutoff: if(pass == 2, do: :c5, else: 80)) end), synth: :saw))
    """)

    {:ok, %{loops: [loop]}} = Song.load(path)
    assert {:ok, _events} = Pass.events(loop, 1)
    assert {:error, message} = Pass.events(loop, 2)
    assert message =~ "part x: synth saw takes cutoff a number, not c5"
  end

  test "gives the notes of a synth that takes no sustain their beats", %{tmp_dir: dir} do
    assert notes(dir, """
           song(music: part(:drum, seq([note(:c3, 0.5), note(:d3, 1.5)]), synth: :berimbau))
           """) == [{0, 48, 0.5}, {0.5, 50, 1.5}]
  end

  test "gives each note of a chord the sustain it is given in a list", %{tmp_dir: dir} do
    assert notes(dir, """
           song(music: part(:keys, note([:c4, :e4], 1, sustain: [2, 0.5]), synth: :tri))
           """) == [{0, 60, 2}, {0, 64, 0.5}]

    assert notes(dir, """
           song(music: part(:keys, note([:e4, :c4], 1, sustain: [0.5, 2], strum: 0.25), synth: :tri))
           """) == [{0, 60, 2}, {0.25, 64, 0.5}]
  end

  test "gives a strummed chord's notes at the beats they sound", %{tmp_dir: dir} do
    assert notes(dir, """
           song(music: part(:guitar, note([:c4, :e4], 2, strum: 0.25), synth: :tri))
           """) == [{0, 60, 2}, {0.25, 64, 2}]
  end
end
