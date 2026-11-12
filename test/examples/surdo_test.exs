defmodule Mx.Examples.SurdoTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/surdo/solo.exs"

  test "the solo plays only surdos: the primeira, then the segunda, then the terceira" do
    output = print()
    parts = Regex.scan(~r/^(\w+), 64 beats/m, output, capture: :all_but_first)
    assert List.flatten(parts) == ~w(primeira segunda terceira)
    refute output =~ "sample "
    refute output =~ ~r/synth: (?!surdo)/
  end

  test "the primeira is muted on the first beat of each bar and open on the second" do
    primeira = part(print(), "primeira")

    for bar <- 0..31 do
      first = 2 * bar
      second = 2 * bar + 1
      assert primeira =~ ~r/^beat #{first} +play note: 36.31, muted: 1, vel: 0.5$/m
      assert primeira =~ ~r/^beat #{second} +play note: 36.31, vel: 0.(7|85)$/m
    end
  end

  test "the segunda answers on the first beat, and the terceira cuts off the beat" do
    output = print()
    assert part(output, "segunda") =~ ~r/^beat 16 +play note: 41, vel: 0.65$/m
    assert part(output, "segunda") =~ ~r/^beat 19.75 +play note: 41, muted: 1, vel: 0.4$/m
    assert part(output, "terceira") =~ ~r/^beat 32.75 +play note: 45, muted: 0, vel: 0.6$/m
    assert part(output, "terceira") =~ ~r/^beat 51.25 +play note: 45, muted: 1, vel: 0.35$/m
  end

  test "the README points to the solo and lists the surdo, and the synth designs license names its recordings" do
    readme = File.read!("README.md")
    assert readme =~ "examples/surdo/solo.exs"
    assert readme =~ "- `surdo` is the large drum"
    notes = File.read!("LICENSE-designs.md")
    assert notes =~ "The surdo is measured from three loops by plotzki"
    assert notes =~ ~s("AKG 414 Surdo Processed.wav" by igorfiche01)
  end

  @tag :tmp_dir
  @tag timeout: 300_000
  test "a minute of the solo renders without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")

    capture_io(:stderr, fn ->
      capture_io(fn -> assert :ok = Mx.Render.render(@song, out, seconds: 60) end)
    end)

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -1
    assert Mx.Recording.seconds(out) >= 60
  end

  defp print, do: capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)

  defp part(output, name) do
    [_, part | _] = String.split(output, ~r/^#{name}, [^\n]*\n/m)
    part |> String.split("\n\n") |> hd()
  end
end
