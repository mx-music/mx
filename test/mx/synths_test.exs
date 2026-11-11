defmodule Mx.SynthsTest do
  use ExUnit.Case, async: true

  test "the README lists every synth mx ships" do
    readme = File.read!("README.md")
    synths = Mx.Synths.synths() |> Enum.sort() |> Enum.join(", ")

    assert readme =~ synths <> "."
  end
end
