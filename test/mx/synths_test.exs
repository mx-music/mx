defmodule Mx.SynthsTest do
  use ExUnit.Case, async: true

  test "the instruments guide lists every synth mx ships" do
    guide = File.read!("documentation/instruments.md")

    # Instruments that tests register join the catalog, so only mxs's own synths are listed.
    {native, _note, _sample, _effects, _effect} = Mx.Engine.Mxs.Native.catalog()
    shipped = MapSet.new(native, fn {name, _specs} -> String.to_atom(name) end)
    synths = Mx.Synths.synths() |> Enum.filter(&(&1 in shipped)) |> Enum.sort() |> Enum.join(", ")

    assert guide =~ synths <> "."
  end
end
