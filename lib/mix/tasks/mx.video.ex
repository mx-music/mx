defmodule Mix.Tasks.Mx.Video do
  @shortdoc "Makes a video of a recording over its waveform or spectrogram"

  @moduledoc """
  Makes an MP4 video of a WAV or AIFF recording that plays its sound over its waveform, with a playhead that crosses the picture once as the recording plays.

      mix mx.video song.wav
      mix mx.video song.wav --picture spectrogram --out song.mp4 --force

  The video is written beside the recording with the extension .mp4 unless `--out` names it, and `--force` writes over a file that exists.
  `--picture spectrogram` plays the recording over its spectrogram instead, drawn with no line at each second.
  The sound is the recording at one gain, which brings its loudest sample to 1.5 dB below full scale, as AAC at 256 kbit/s unless `--bitrate` gives another count.
  The task prints the video's length and size, and warns when it is over the 10 MB GitHub allows for a video on its free plan.
  ffmpeg joins the picture and the sound, so it has to be installed.
  """

  use Mix.Task

  alias Mx.Video

  @impl true
  def run(args) when is_list(args) do
    strict = [out: :string, picture: :string, bitrate: :integer, force: :boolean]
    {opts, [path]} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".mp4" end)
    picture = opts |> Keyword.get(:picture, "waveform") |> picture()
    written = Video.write(path, out, [picture: picture] ++ Keyword.take(opts, [:bitrate, :force]))

    case written do
      {:ok, seconds, bytes} ->
        {line, warning} = Video.report(out, seconds, bytes)
        Mix.shell().info(line)
        if warning, do: Mix.shell().error(warning)

      {:error, message} ->
        Mix.raise(message)
    end
  end

  defp picture("waveform"), do: :waveform
  defp picture("spectrogram"), do: :spectrogram
  defp picture(other), do: Mix.raise("--picture is waveform or spectrogram, not #{other}")
end
