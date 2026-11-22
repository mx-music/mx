defmodule Mx.SynthsTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs.Native

  test "the instruments guide lists every synth mx ships" do
    guide = File.read!("documentation/instruments.md")

    # Instruments that tests register join the catalog, so only mxs's own synths are listed.
    {native, _note, _sample, _effects, _effect, _input} = Native.catalog()
    shipped = MapSet.new(native, fn {name, _specs} -> name end)
    synths = Mx.Synths.synths() |> Enum.filter(&(&1 in shipped)) |> Enum.sort() |> Enum.join(", ")

    assert guide =~ synths <> "."
  end

  test "the instruments guide lists every effect mx ships, each with a line for its options" do
    guide = File.read!("documentation/instruments.md")

    # Effects that tests register join the catalog, so only mxs's own effects are listed.
    {_synths, _note, _sample, native, _effect, _input} = Native.catalog()
    effects = native |> Enum.map(fn {name, _specs} -> name end) |> Enum.sort()

    assert guide =~ "\n" <> Enum.join(effects, ", ") <> ".\n"

    for effect <- effects, effect != "level" do
      assert guide =~ "`#{effect}`", "the guide has no line for #{effect}"
    end

    assert guide =~ "An effect's time is in beats and follows the tempo unless its name ends in"
    assert guide =~ "`amp`, `pre_amp` and `mix` are plain factors, not decibels"
    assert guide =~ "is a MIDI note number.\n"

    assert guide =~
             "- `pitch_shift` takes `pitch`, how many semitones the sound is shifted by, from -24 to 24, and delays the sound by up to 40 ms."
  end

  test "an effect's time that is not in beats names its unit" do
    {_synths, _note, _sample, native, _effect, _input} = Native.catalog()

    for {effect, specs} <- native, %{name: name, kind: kind} <- specs do
      unit =
        cond do
          String.ends_with?(name, "_ms") -> "ms"
          String.ends_with?(name, "_seconds") -> "seconds"
          true -> nil
        end

      assert (kind in ["ms", "seconds"] and kind == unit) or
               (kind not in ["ms", "seconds"] and unit == nil),
             "#{effect}'s #{name} is declared in #{kind}"

      refute String.ends_with?(name, "_time"), "#{effect}'s #{name} names no unit"
    end
  end
end
