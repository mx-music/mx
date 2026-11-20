defmodule Mx.SynthsFamilyTest do
  use ExUnit.Case, async: true, group: :engine

  test "the flute is one of the winds, meant to play from B3 to D flat 7" do
    assert Mx.Synths.family(:flute) == :winds
    assert Mx.Synths.range(:flute) == {59, 97}
  end

  test "the clarinet plays the notes it was fitted to, from D3 to C7" do
    assert Mx.Synths.family(:clarinet) == :winds
    assert Mx.Synths.range(:clarinet) == {50, 96}
  end

  test "saw is one of the synths, with no range" do
    assert Mx.Synths.family(:saw) == :synths
    assert Mx.Synths.range(:saw) == nil
  end

  test "every synth mxs ships has a family" do
    {native, _note, _sample, _effects, _effect, _input} = Mx.Engine.Mxs.Native.catalog()

    families =
      for {name, _specs} <- native, Mx.Synths.exists?(name), do: Mx.Synths.family(name)

    assert families != []

    assert Enum.all?(
             families,
             &(&1 in [:keys, :plucked_strings, :bowed_strings, :winds, :mallets, :synths, :drums])
           )
  end

  @tag :engine
  @tag :tmp_dir
  test "a flute below its range plays as before", %{tmp_dir: dir} do
    song = Path.join(dir, "low.exs")

    File.write!(
      song,
      "import Mx\nsong(tempo: 60, music: part(:flute, seq(c3: 1), synth: :flute))\n"
    )

    wav = Path.join(dir, "low.wav")
    :ok = Mx.Render.render(song, wav, seconds: 1.5, force: true)
    {:ok, audio} = Mx.Audio.read(wav)
    assert Enum.max(Enum.map(audio.samples, &abs/1)) > 0.01
  end
end
