defmodule Mx.PageTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

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

  test "gives the song's meter, 4 when it gives none", %{tmp_dir: dir} do
    {song, path} = load(dir, "song(meter: 3, music: part(:waltz, seq(c4: 3), synth: :fm))")
    assert {:ok, %{meter: 3}} = Page.data(song, path, 1.0)

    {song, path} = load(dir, "song(music: part(:march, seq(c4: 4), synth: :fm))")
    assert {:ok, %{meter: 4}} = Page.data(song, path, 1.0)
  end

  test "gives a hit the seconds it sounds when its sample or options say, and 0 otherwise", %{
    tmp_dir: dir
  } do
    sample = Path.join(dir, "second.wav")
    data = :binary.copy(<<0.0::little-float-32>>, 48_000)

    File.write!(
      sample,
      "RIFF" <>
        <<36 + byte_size(data)::little-32>> <>
        "WAVEfmt " <>
        <<16::little-32, 3::little-16, 1::little-16, 48_000::little-32, 192_000::little-32,
          4::little-16, 32::little-16>> <> "data" <> <<byte_size(data)::little-32>> <> data
    )

    {{song, path}, warnings} =
      with_io(:stderr, fn ->
        load(dir, """
        song(
          tempo: 120,
          music:
            together([
              part(:whole, sample(#{inspect(sample)}, 4)),
              part(:fast, sample(#{inspect(sample)}, 4, rate: 2)),
              part(:held, sample(#{inspect(sample)}, 4, sustain: 0.5, release: 0.25)),
              part(:tri, steps("x...", 1), synth: :triangle, defaults: [sustain: 0.5, release: 1]),
              part(:kick, steps("x...", 1), synth: :kick)
            ])
        )
        """)
      end)

    assert warnings =~ "sample #{sample} is silent"
    assert {:ok, %{parts: parts}} = Page.data(song, path, 2.0)

    assert Enum.map(parts, & &1.hits) == [
             [[0.0, 1.0, 1.0]],
             [[0.0, 1.0, 0.5]],
             [[0.0, 1.0, 0.375]],
             [[0.0, 1.0, 0.75]],
             [[0.0, 1.0, 0.0]]
           ]
  end

  test "shows a song that plays until mx stops for as long as its sound lasts", %{tmp_dir: dir} do
    {song, path} =
      load(dir, "song(tempo: 60, music: repeat(part(:a, seq(c4: 1, r: 1), synth: :fm)))\n")

    assert {:ok, %{sections: sections, parts: [%{notes: notes}]}} = Page.data(song, path, 5.0)
    assert sections == [[0.0, 2], [2.0, 2], [4.0, 2]]
    assert Enum.map(notes, &hd/1) == [0.0, 2.0, 4.0]
  end

  describe "whole/3" do
    test "shows all of a song that ends, and says that it ends", %{tmp_dir: dir} do
      {song, path} =
        load(dir, "song(tempo: 60, music: part(:a, seq(c4: 1, e4: 1, g4: 2), synth: :fm))\n")

      assert {:ok, %{ends: true, seconds: 4.0, parts: [%{notes: notes}]}} = Page.whole(song, path)
      assert Enum.map(notes, &hd/1) == [0.0, 1.0, 2.0]
    end

    test "shows a song that plays until stopped one time through", %{tmp_dir: dir} do
      {song, path} =
        load(dir, "song(tempo: 60, music: repeat(part(:a, seq(c4: 1, r: 1), synth: :fm)))\n")

      assert {:ok, %{ends: false, sections: [[+0.0, 2]], parts: [%{notes: [_one]}]}} =
               Page.whole(song, path)
    end

    test "given the file's text, reads no file", %{tmp_dir: dir} do
      {song, path} = load(dir, "song(tempo: 60, music: part(:a, seq(c4: 1), synth: :fm))\n")
      File.rm!(path)

      assert {:ok, %{source: "the text"}} = Page.whole(song, path, "the text")
    end
  end
end
