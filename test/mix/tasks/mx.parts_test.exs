defmodule Mix.Tasks.Mx.PartsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Parts

  test "prints one line for each harmonic of the note, then its partners, thump and knock" do
    {:ok, parts} = Mx.Piano.parts(note: 60, vel: 0.6)
    output = capture_io(fn -> Parts.run(~w(piano --note 60 --vel 0.6)) end)
    lines = String.split(output, "\n", trim: true)

    assert hd(lines) == "piano, note 60, vel 0.6: #{length(parts.harmonics)} harmonics"
    harmonics = lines |> tl() |> Enum.take_while(&(&1 != "  partners"))
    assert length(harmonics) == length(parts.harmonics)
    assert hd(harmonics) == "      261.6 Hz   1.00   +0.0 dB  8.79 s"
    assert Enum.any?(lines, &String.starts_with?(&1, "  thump "))
    assert Enum.any?(lines, &String.starts_with?(&1, "  knock "))
  end

  test "takes a note by name" do
    by_name = capture_io(fn -> Parts.run(~w(piano --note C4)) end)
    by_number = capture_io(fn -> Parts.run(~w(piano --note 60)) end)
    assert by_name == by_number
  end

  test "refuses a note outside the piano's keys, and any synth but the piano" do
    assert_raise Mix.Error, "the piano's keys are from A0 to C8, MIDI notes 21 to 108", fn ->
      Parts.run(~w(piano --note 20))
    end

    assert_raise Mix.Error, "only the piano's parts are known, not organ's", fn ->
      Parts.run(~w(organ))
    end
  end

  test "the guide to instruments names mix mx.parts" do
    assert File.read!("documentation/instruments.md") =~ "mx parts piano --note 60 --vel 0.6"
  end
end
