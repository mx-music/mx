defmodule Mx.SynthsTest do
  use ExUnit.Case, async: true

  test "the instruments guide lists every synth mx ships" do
    guide = File.read!("documentation/instruments.md")

    # Instruments that tests register join the catalog, so only mxs's own synths are listed.
    {native, _note, _sample, _effects, _effect, _input} = Mx.Engine.Mxs.Native.catalog()
    shipped = MapSet.new(native, fn {name, _specs} -> name end)
    synths = Mx.Synths.synths() |> Enum.filter(&(&1 in shipped)) |> Enum.sort() |> Enum.join(", ")

    assert guide =~ synths <> "."
  end

  test "the instruments guide lists every effect mx ships, each with a line for its options" do
    guide = File.read!("documentation/instruments.md")

    # Effects that tests register join the catalog, so only mxs's own effects are listed.
    {_synths, _note, _sample, native, _effect, _input} = Mx.Engine.Mxs.Native.catalog()
    effects = native |> Enum.map(fn {name, _specs} -> name end) |> Enum.sort()

    assert guide =~ "\n" <> Enum.join(effects, ", ") <> ".\n"

    for effect <- effects, effect != "level" do
      assert guide =~ "`#{effect}`", "the guide has no line for #{effect}"
    end

    assert guide =~
             "- `pitch_shift` takes `pitch`, how many semitones the sound is shifted by, from -24 to 24, and delays the sound by up to 40 ms."
  end
end
