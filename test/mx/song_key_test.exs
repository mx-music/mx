defmodule Mx.SongKeyTest do
  use ExUnit.Case, async: true

  defp load(source), do: Mx.Song.load("key.exs", source: source)

  test "a song that states e minor is in e minor" do
    {:ok, song} = load("import Mx\nsong(key: :em, music: part(:a, seq(e4: 1), synth: :piano))\n")
    assert song.key == :em
  end

  test "a module song states its key where it states its tempo" do
    source = """
    defmodule InB do
      use Mx.Song, tempo: 90, key: :bb
      part :a, synth: :piano
      def song, do: part(:a, seq(bb3: 1))
    end
    """

    {:ok, song} = load(source)
    assert song.key == :bb
  end

  test "a song that states no key is in none" do
    {:ok, song} = load("import Mx\nsong(music: part(:a, seq(c4: 1), synth: :piano))\n")
    assert song.key == nil
  end

  test "a key mx does not know is refused, naming it" do
    {:error, message} =
      load("import Mx\nsong(key: :h, music: part(:a, seq(c4: 1), synth: :piano))\n")

    assert message =~ "song takes key: as a key such as :d, :bm or :fsm, not :h"
  end

  test "choro states the key it starts in, G major" do
    {:ok, song} = Mx.Song.load("examples/choro.exs")
    assert song.key == :g
  end
end
