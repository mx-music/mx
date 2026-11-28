defmodule Mix.Tasks.Mx.Waveform do
  @shortdoc "Draws the waveform of a recording into an image"

  @moduledoc """
  Draws the waveform of a WAV or AIFF recording into a PNG image: a row of bars, each as tall as
  its slice of the recording is loud.

      mx waveform song.wav
      mx waveform song.wav --out bars.png --width 900 --height 120

  The image is written beside the recording with the extension .png unless `--out` names it.
  It is 1500 pixels wide and 150 high unless `--width` and `--height` give another size.
  """

  use Mix.Task

  alias Mx.Waveform

  @impl true
  def run(args) when is_list(args) do
    strict = [out: :string, width: :integer, height: :integer]
    {opts, [path]} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".png" end)

    case Waveform.write(path, out, Keyword.take(opts, [:width, :height])) do
      :ok -> IO.puts("Wrote #{out}")
      {:error, message} -> Mx.Command.fail(message)
    end
  end
end
