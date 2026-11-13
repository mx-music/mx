defmodule Mx.Examples.BinIchGleichTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @dir "examples/bin_ich_gleich"

  @moduletag :tmp_dir

  @tag :audiveris
  @tag timeout: 300_000
  test "the scan is what mix mx.scan reads from the page, as the README gives it", %{tmp_dir: dir} do
    out = Path.join(dir, "chorale.mxl")

    args =
      ~r/^mix mx\.scan examples\/bin_ich_gleich\/page\.pdf .*$/m
      |> readme_args()
      |> Enum.map(&if(&1 == Path.join(@dir, "chorale.mxl"), do: out, else: &1))

    capture_io(fn -> Mix.Tasks.Mx.Scan.run(args) end)

    {:ok, scanned} = Mx.Score.read(out)
    {:ok, example} = Mx.Score.read(Path.join(@dir, "chorale.mxl"))
    assert scanned.parts == example.parts
  end

  test "the page's provenance and the reference encoding's license are kept beside them" do
    license = File.read!(Path.join(@dir, "LICENSE.md"))

    assert license =~ "https://archive.org/details/bach-gesellschaft-ausgabe"
    assert license =~ "Redistribution and use in source and binary forms"
  end

  defp readme_args(pattern) do
    [command] = Regex.run(pattern, File.read!("README.md"))
    command |> OptionParser.split() |> Enum.drop(2)
  end
end
