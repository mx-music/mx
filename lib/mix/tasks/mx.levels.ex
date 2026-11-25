defmodule Mix.Tasks.Mx.Levels do
  @shortdoc "Prints a recording's levels over time as comma-separated values"

  @moduledoc """
  Prints the levels of a WAV or AIFF recording over time as comma-separated values, as `Mx.Levels` works them out, for a picture that reacts to what was played.

      mx levels performance.wav
      mx levels performance.wav --per-second 60 > levels.csv
      mx levels performance.wav --strokes

  The first line names the columns, and each line after it is a row: the second it starts at, the level of the whole sound, the level of each octave from 20 Hz to 20,480 Hz, all in dB under the recording's loudest row, and the brightness, the frequency in Hz that half the sound's energy lies under.
  `--per-second` is the rows a second, 30 unless given, and each row covers all the sound from its second to the next row's.
  `--strokes` prints the strokes in place of the rows: the second each sound starts, and its level in dB under the loudest stroke's.
  """

  use Mix.Task

  alias Mx.Levels

  @impl true
  def run(args) when is_list(args) do
    strict = [per_second: :integer, strokes: :boolean]

    case OptionParser.parse!(args, strict: strict) do
      {opts, [path]} -> print(path, opts)
      _other -> Mx.Command.fail("usage: mix mx.levels RECORDING [--per-second 30] [--strokes]")
    end
  end

  defp print(path, opts) do
    if opts[:strokes], do: print_strokes(path), else: print_rows(path, opts)
  end

  defp print_rows(path, opts) do
    case Levels.rows(path, Keyword.take(opts, [:per_second])) do
      {:ok, rows} ->
        bands = for {low, high} <- Levels.bands(), do: "#{low}-#{high} Hz"
        header = ["seconds", "level"] ++ bands ++ ["brightness"]
        header |> Enum.join(",") |> IO.puts()

        for row <- rows do
          values = [seconds(row.at), decibels(row.level)] ++ Enum.map(row.bands, &decibels/1)
          line = values ++ [round(row.brightness)]
          line |> Enum.join(",") |> IO.puts()
        end

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp print_strokes(path) do
    case Levels.strokes(path) do
      {:ok, strokes} ->
        IO.puts("seconds,level")
        for stroke <- strokes, do: IO.puts("#{seconds(stroke.at)},#{decibels(stroke.level)}")

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp seconds(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
  defp decibels(value), do: :erlang.float_to_binary(value / 1, decimals: 1)
end
