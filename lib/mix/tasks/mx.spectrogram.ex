defmodule Mix.Tasks.Mx.Spectrogram do
  @shortdoc "Draws a spectrogram of a recording into an image"

  @moduledoc """
  Draws a spectrogram of a WAV or AIFF recording into a PNG image, with seconds across and octaves up the side.

      mix mx.spectrogram Guitar.mf.sulA.A2B2.aif
      mix mx.spectrogram Guitar.mf.sulA.A2B2.aif --out a-string.png

  The image is written beside the recording with the extension .png unless `--out` names it.
  """

  use Mix.Task

  alias Mx.{Audio, Spectrogram}

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} = OptionParser.parse!(args, strict: [out: :string])
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".png" end)

    case Audio.read(path) do
      {:ok, %{rate: rate, samples: samples}} ->
        Spectrogram.write(samples, rate, out)
        IO.puts("Wrote #{out}")

      {:error, message} ->
        Mix.raise(message)
    end
  end
end
