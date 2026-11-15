defmodule Mx.Spectrogram do
  @moduledoc """
  Draws a spectrogram of a recording into a PNG image: seconds across, at 100 pixels a second unless `per_second:` gives another count, and frequency up the side on a scale of octaves.

  The side spans the ten octaves from 20 Hz to 20,480 Hz, 48 pixels each, with a faint line at every octave from 20 Hz and every second.
  Brightness follows the level in dB, from 100 dB below the recording's loudest point up to it.
  Each column is the spectrum of 4096 samples, or of the seconds `window:` gives when that is fewer: a long window tells harmonics apart and a short one, such as 0.004, shows how the level moves within a note.
  A column that covers more sound than its window shows the loudest level each frequency reaches anywhere in the sound it covers, so a narrow picture of a long recording skips no note.
  The columns are worked out by `Mx.Engine.Mxs.Native`, from the recording's data as it is in the file.
  """

  alias Mx.{Audio, PNG}
  alias Mx.Engine.Mxs.Native

  @fft 4096
  @per_second 100
  @height 480

  @doc "Writes a spectrogram of the samples to a PNG file."
  def write(samples, rate, path, opts \\ [])
      when is_list(samples) and is_integer(rate) and is_binary(path) and is_list(opts) do
    stack([{samples, rate}], path, opts)
  end

  @doc """
  Writes the spectrograms of several sounds to one PNG file, one above another from the first, so they can be compared moment by moment.

  A sound is the path of a WAV or AIFF recording, or `{samples, rate}`.
  It returns `:ok`, or `{:error, "cannot read PATH"}` for a recording it cannot read.

  - `from:` and `seconds:` draw only a stretch of each sound, from a second and for so many seconds.
  - `per_second:` is the pixels a second takes across, and `width:` instead gives the picture's width in pixels, which the stretch fills.
  - `window:` is the seconds of sound in each column.
  - `second_lines: false` leaves out the line at each second.
  """
  def stack(sounds, path, opts \\ [])
      when is_list(sounds) and is_binary(path) and is_list(opts) do
    with {:ok, images} <- images(sounds, opts) do
      width = images |> Enum.map(&elem(&1, 0)) |> Enum.max()

      rows =
        for {own, pixels} <- images,
            <<row::binary-size(^own * 3) <- pixels>>,
            do: [row, :binary.copy(<<0, 0, 0>>, width - own)]

      File.write!(path, PNG.encode(width, length(rows), rows))
    end
  end

  defp images(sounds, opts) do
    Enum.reduce_while(sounds, {:ok, []}, fn sound, {:ok, images} ->
      case raw(sound) do
        {:ok, format, data} -> {:cont, {:ok, images ++ [image(format, data, opts)]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp raw({samples, rate}) do
    data = for sample <- samples, into: <<>>, do: <<sample / 1::float-little-64>>
    {:ok, %{rate: rate, channels: 1, bits: 64, kind: :float_little}, data}
  end

  defp raw(path), do: Audio.raw(path)

  defp image(%{rate: rate, channels: channels, bits: bits, kind: kind}, data, opts) do
    frames = div(byte_size(data), div(bits, 8) * channels)
    from = min(round(Keyword.get(opts, :from, 0.0) * rate), frames)
    seconds = opts[:seconds]
    count = if seconds, do: min(round(seconds * rate), frames - from), else: frames - from
    size = min(round(Keyword.get(opts, :window, @fft / rate) * rate), @fft)

    {width, hop} =
      columns(opts[:width], count, rate / Keyword.get(opts, :per_second, @per_second))

    per_second = if Keyword.get(opts, :second_lines, true), do: rate / hop

    pixels =
      Native.spectrogram(
        data,
        {Atom.to_string(kind), bits, channels},
        rate / 1,
        {from, count},
        {width, hop, size},
        per_second
      )

    @height = div(byte_size(pixels), width * 3)
    {width, pixels}
  end

  defp columns(nil, count, hop), do: {max(ceil(count / hop), 1), hop}
  defp columns(width, count, _hop), do: {width, max(count, 1) / width}
end
