defmodule Mix.Tasks.Mx.Spectrogram do
  @shortdoc "Draws a spectrogram of a recording into an image"

  @moduledoc """
  Draws a spectrogram of a WAV or AIFF recording into a PNG image, with seconds across and octaves up the side.

      mx spectrogram Guitar.mf.sulA.A2B2.aif
      mx spectrogram Guitar.mf.sulA.A2B2.aif --out a-string.png

  The image is written beside the recording with the extension .png unless `--out` names it.

      mx spectrogram "cuica (2).wav" solo.wav --from 1 --seconds 2.4 --per-second 400 --window 4

  Several recordings are drawn into one image, one above another from the first, beside which the image is written, each against its own loudest point, so a synth's render can be compared with a recording moment by moment.
  `--from` and `--seconds` draw only a stretch of each recording, from a second and for so many seconds.
  `--per-second` is the pixels a second takes across, 100 unless given.
  `--width` gives the image's width in pixels in place of `--per-second`, and the stretch drawn fills it.
  `--no-seconds` leaves out the line at each second and keeps the line at each octave, for a long recording drawn at a few pixels a second.
  `--window` is the milliseconds of sound in each column, 4096 samples unless given: a long window tells the harmonics apart, and a short one, such as 4, shows how the level moves within a note and where notes join.
  """

  use Mix.Task

  alias Mx.Spectrogram

  @impl true
  def run(args) when is_list(args) do
    strict = [
      out: :string,
      from: :float,
      seconds: :float,
      per_second: :integer,
      width: :integer,
      window: :float,
      no_seconds: :boolean
    ]

    {opts, [path | _] = paths} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".png" end)
    window = if opts[:window], do: [window: opts[:window] / 1000], else: []
    lines = [second_lines: !opts[:no_seconds]]
    drawn = Keyword.take(opts, [:from, :seconds, :per_second, :width]) ++ window ++ lines

    case Spectrogram.stack(paths, out, drawn) do
      :ok -> IO.puts("Wrote #{out}")
      {:error, message} -> Mx.Command.fail(message)
    end
  end
end
