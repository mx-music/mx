defmodule Mx.Examples.AccordionTest do
  # The render keeps the engine busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @song "examples/solo/accordion.exs"

  test "the solo plays only the accordion: a low theme, the theme high and dry, chords, and an ending" do
    output = print()
    parts = Regex.scan(~r/^(\w+), 111 beats/m, output, capture: :all_but_first)
    assert List.flatten(parts) == ~w(theme high chords ending)
    refute output =~ "sample "
    assert output =~ ~r/^beat 0 +play 52 vel: 0.6, sustain: 0.9, release: 0.1$/m
    assert output =~ ~r/^beat 16 +play 65 vel: 0.5, sustain: 0.45, release: 0.1$/m
  end

  test "the high theme sounds one reed and the low theme two" do
    output = print()

    assert part(output, "high") =~
             ~r/^beat 24 +play 64 vel: 0.6, sustain: 0.45, release: 0.1, detune: 0$/m

    refute part(output, "theme") =~ "detune"
    assert part(output, "ending") =~ ~r/^beat 105 +play 57 vel: 0.6, sustain: 5.4, release: 0.1$/m
  end

  test "the chords are struck on the first beat and short on the second and third" do
    chords = part(print(), "chords")

    for note <- [57, 60, 64] do
      assert chords =~ ~r/^beat 48 +play #{note} vel: 0.6, sustain: 0.9, release: 0.1, amp: 0.6$/m

      assert chords =~
               ~r/^beat 49 +play #{note} vel: 0.45, sustain: 0.35, release: 0.08, amp: 0.6$/m
    end

    assert chords =~ ~r/^beat 54 +play 56 /m
    assert chords =~ ~r/^beat 60 +play 65 /m
  end

  test "the README points to the solo and lists the accordion, and the synth designs license names its recordings" do
    readme = File.read!("README.md")
    assert readme =~ "examples/solo/accordion.exs"
    assert readme =~ "- `accordion` is an accordion's right hand"
    notes = File.read!("LICENSE-designs.md")
    assert notes =~ ~s(The accordion is measured from "Accordeon master" by hammondman)
    assert notes =~ ~s("Accordion wav samples" by hammondman)
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
