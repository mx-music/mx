defmodule Mx.PageTest do
  use ExUnit.Case, async: true

  alias Mx.{Page, Song}

  @moduletag :tmp_dir

  defp load(dir, body) do
    path = Path.join(dir, "song.exs")
    File.write!(path, "import Mx\n" <> body)
    {:ok, song} = Song.load(path)
    {song, path}
  end

  test "gives each part's notes and hits in seconds, and the song's sections and beats", %{
    tmp_dir: dir
  } do
    {song, path} =
      load(dir, """
      song(
        tempo: 120,
        music:
          seq([
            together([
              part(:lead, seq([{:r, 2}, {:c4, 2}]), synth: :fm),
              part(:drum, steps("x.x.", 1), synth: :kick)
            ]),
            part(:lead, seq(e4: 1, r: 1), synth: :fm)
          ])
      )
      """)

    assert {:ok, data} = Page.data(song, path, 3.5)
    assert data.file == "song.exs"
    assert data.sections == [[0.0, 4], [2.0, 2]]
    assert data.beats == [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

    assert [lead, drum] = data.parts
    assert lead.name == :lead
    assert lead.synth == "fm"
    assert lead.notes == [[1.0, 1.0, 60, 1.0, 0], [2.0, 0.5, 64, 1.0, 0]]
    assert lead.hits == []
    assert drum.notes == []
    assert Enum.map(drum.hits, &hd/1) == [0.0, 1.0]
  end

  test "shows a song that plays until mx stops for as long as its sound lasts", %{tmp_dir: dir} do
    {song, path} =
      load(dir, "song(tempo: 60, music: repeat(part(:a, seq(c4: 1, r: 1), synth: :fm)))\n")

    assert {:ok, %{sections: sections, parts: [%{notes: notes}]}} = Page.data(song, path, 5.0)
    assert sections == [[0.0, 2], [2.0, 2], [4.0, 2]]
    assert Enum.map(notes, &hd/1) == [0.0, 2.0, 4.0]
  end
end
