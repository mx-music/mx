defmodule Mx.Spectrogram do
  @moduledoc """
  Draws a spectrogram of a recording into a PNG image: seconds across, at 100 pixels a second, and frequency up the side on a scale of octaves.

  The side spans the ten octaves from 20 Hz to 20,480 Hz, 48 pixels each, with a faint line at every octave from 20 Hz and every second.
  Brightness follows the level in dB, from 100 dB below the loudest point up to it.
  """

  alias Mx.FFT

  @fft 4096
  @per_second 100
  @low 20
  @octaves 10
  @per_octave 48
  @range 100

  @doc "Writes a spectrogram of the samples to a PNG file."
  def write(samples, rate, path) when is_list(samples) and is_integer(rate) and is_binary(path) do
    sound = List.to_tuple(samples)
    hop = rate / @per_second
    width = max(ceil(tuple_size(sound) / hop), 1)
    height = @octaves * @per_octave
    bins = for row <- (height - 1)..0//-1, do: @low * 2 ** (row / @per_octave) / (rate / @fft)

    columns =
      0..(width - 1)
      |> Task.async_stream(&column(sound, round(&1 * hop), bins), timeout: :infinity)
      |> Enum.map(fn {:ok, column} -> column end)

    loudest = columns |> Enum.map(&Enum.max/1) |> Enum.max()

    rows =
      columns
      |> Enum.zip_with(& &1)
      |> Enum.with_index(fn row, top ->
        pixels =
          row
          |> Enum.with_index(fn level, left ->
            pixel(level - loudest, line?(left, top, height))
          end)
          |> IO.iodata_to_binary()

        <<0>> <> pixels
      end)

    File.write!(path, png(width, height, IO.iodata_to_binary(rows)))
  end

  defp column(sound, from, bins) do
    frame =
      for at <- from..(from + @fft - 1),
          do: if(at < tuple_size(sound), do: elem(sound, at), else: 0.0)

    spectrum = frame |> FFT.magnitudes() |> List.to_tuple()

    for position <- bins do
      below = min(floor(position), tuple_size(spectrum) - 2)
      low = elem(spectrum, below)
      magnitude = low + (position - below) * (elem(spectrum, below + 1) - low)
      20 * :math.log10(max(magnitude, 0.0) + 1.0e-12)
    end
  end

  defp line?(left, top, height) do
    rem(height - 1 - top, @per_octave) == 0 or rem(left, @per_second) == 0
  end

  # Black through purple and orange to pale yellow as the level rises.
  defp pixel(db, line?) do
    loudness = min(max((db + @range) / @range, 0.0), 1.0)
    red = channel(loudness * 1.6)
    green = channel(loudness * 1.6 - 0.6)
    blue = channel(blue(loudness))

    if line? do
      <<max(red, 60), max(green, 60), max(blue, 60)>>
    else
      <<red, green, blue>>
    end
  end

  defp blue(loudness) when loudness < 0.4, do: loudness * 1.5
  defp blue(loudness), do: max(0.0, 0.6 - (loudness - 0.4) * 1.5) + max(0.0, loudness - 0.85) * 4

  defp channel(level), do: round(255 * min(max(level, 0.0), 1.0))

  defp png(width, height, rows) do
    header = <<width::32, height::32, 8, 2, 0, 0, 0>>

    <<137, "PNG", 13, 10, 26, 10>> <>
      chunk("IHDR", header) <> chunk("IDAT", :zlib.compress(rows)) <> chunk("IEND", <<>>)
  end

  defp chunk(type, body) do
    <<byte_size(body)::32>> <> type <> body <> <<:erlang.crc32(type <> body)::32>>
  end
end
