defmodule Mix.Tasks.Mx.Spectrogram do
  @shortdoc "Draws a spectrogram of a recording into an image"

  @moduledoc """
  Draws a spectrogram of a WAV or AIFF recording into a PNG image, with seconds across and octaves up the side.

      mix mx.spectrogram Guitar.mf.sulA.A2B2.aif
      mix mx.spectrogram Guitar.mf.sulA.A2B2.aif --out a-string.png

  The image is written beside the recording with the extension .png unless `--out` names it.

      mix mx.spectrogram "cuica (2).wav" solo.wav --from 1 --seconds 2.4 --per-second 400 --window 4

  Several recordings are drawn into one image, one above another from the first, beside which the image is written, each against its own loudest point, so a synth's render can be compared with a recording moment by moment.
  `--from` and `--seconds` draw only a stretch of each recording, from a second and for so many seconds.
  `--per-second` is the pixels a second takes across, 100 unless given.
  `--window` is the milliseconds of sound in each column, 4096 samples unless given: a long window tells the harmonics apart, and a short one, such as 4, shows how the level moves within a note and where notes join.
  """

  use Mix.Task

  alias Mx.{Audio, Spectrogram}

  @impl true
  def run(args) when is_list(args) do
    strict = [out: :string, from: :float, seconds: :float, per_second: :integer, window: :float]
    {opts, [path | _] = paths} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".png" end)
    window = if opts[:window], do: [window: opts[:window] / 1000], else: []
    sounds = Enum.map(paths, &stretch(&1, opts))
    Spectrogram.stack(sounds, out, Keyword.take(opts, [:per_second]) ++ window)
    IO.puts("Wrote #{out}")
  end

  defp stretch(path, opts) do
    case Audio.read(path) do
      {:ok, %{rate: rate, samples: samples}} ->
        from = Enum.drop(samples, round(Keyword.get(opts, :from, 0.0) * rate))
        seconds = opts[:seconds]
        {if(seconds, do: Enum.take(from, round(seconds * rate)), else: from), rate}

      {:error, message} ->
        Mix.raise(message)
    end
  end
end
