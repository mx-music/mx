defmodule Mix.Tasks.Mx.Parts do
  @shortdoc "Prints what a note of the piano is made of, without playing it"

  @moduledoc """
  Prints what a note of mx's piano is made of, worked out from its options without playing it, as
  `Mx.Piano` describes.

      mx parts piano --note 60 --vel 0.6
      mx parts piano --note C2 --vel 1 --pedal 1

  `--note` is a name such as C4 or Bb3, or a MIDI number, from A0 to C8, and 52 unless given.
  `--vel`, `--pedal`, `--aftersound`, `--uneven`, `--instrument` and `--knock` give the piano's
  other options, each at its default unless given.
  It prints one line for each harmonic, lowest first, as `mx measure --partials` prints a recorded
  hit's partials: the frequency in Hz, the ratio to the first harmonic, the level in dB against
  the loudest harmonic, and the seconds it takes to fade 60 dB.
  Then come the partners that ring beside the harmonics, each with the harmonic it belongs to and
  whether it is that harmonic's slow stage or a twin that beats against it, then the thump and the
  knock.
  """

  use Mix.Task

  alias Mx.{Notes, Piano}

  @impl true
  def run(args) when is_list(args) do
    Mx.Command.config()

    strict = [
      note: :string,
      vel: :float,
      pedal: :float,
      aftersound: :float,
      uneven: :float,
      instrument: :integer,
      knock: :float
    ]

    case OptionParser.parse!(args, strict: strict) do
      {opts, ["piano"]} -> print(opts)
      {_opts, [other]} -> Mx.Command.fail("only the piano's parts are known, not #{other}'s")
      {_opts, _other} -> Mx.Command.fail("usage: mix mx.parts piano --note 60 --vel 0.6")
    end
  end

  defp print(opts) do
    options = Keyword.update(opts, :note, 52, &note!/1)

    case Piano.parts(options) do
      {:ok, parts} ->
        Enum.each(parts.warnings, &Mx.Command.info("warning: #{&1}"))
        given = Enum.map_join(options, ", ", fn {name, value} -> "#{name} #{value}" end)
        count = length(parts.harmonics)
        IO.puts("piano, #{given}: #{count} harmonics")
        [first | _] = parts.harmonics
        Enum.each(parts.harmonics, &IO.puts(harmonic(&1, first.hz)))
        IO.puts("  partners")
        Enum.each(parts.partners, &IO.puts(partner(&1)))
        IO.puts("  thump #{decibels(parts.thump.level)} under #{hz(parts.thump.below_hz)}")
        IO.puts("  knock #{knock(parts.knock)}")

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp note!(text) do
    Notes.from_text(text)
  rescue
    ArgumentError -> Mx.Command.fail("unknown note #{text}")
  end

  defp harmonic(%{hz: hz, level: level, fade: fade}, first) do
    ratio = :erlang.float_to_binary(hz / first, decimals: 2)

    "    " <>
      String.pad_leading(hz(hz), 10) <>
      String.pad_leading(ratio, 7) <>
      String.pad_leading(decibels(level), 10) <> String.pad_leading(seconds(fade), 8)
  end

  defp partner(%{harmonic: number, kind: kind, hz: hz, level: level, fade: fade}) do
    "    " <>
      String.pad_leading("#{number} #{kind}", 9) <>
      String.pad_leading(hz(hz), 11) <>
      String.pad_leading(decibels(level), 10) <> String.pad_leading(seconds(fade), 9)
  end

  defp knock(nil), do: "none"

  defp knock(%{level: level, resonances: resonances}) do
    at = Enum.map_join(resonances, ", ", &round/1)
    "#{decibels(level)}, through the soundboard at #{at} Hz"
  end

  defp hz(value), do: :erlang.float_to_binary(value, decimals: 1) <> " Hz"
  defp seconds(value), do: :erlang.float_to_binary(value, decimals: 2) <> " s"

  defp decibels(value) do
    text = :erlang.float_to_binary(value, decimals: 1)
    if value >= 0, do: "+" <> text <> " dB", else: text <> " dB"
  end
end
