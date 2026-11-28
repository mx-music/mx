defmodule Mx.Video do
  @moduledoc """
  Makes an MP4 video of a recording that plays its sound over a picture of it, with a playhead
  that crosses the picture once as the recording plays.

  The picture is the recording's waveform, as `Mx.Waveform` draws it, or with
  `picture: :spectrogram` its spectrogram, as `Mx.Spectrogram` draws it 1500 pixels wide with no
  line at each second.
  Over the waveform the playhead is the boundary between the bars in amber, which have played, and
  the bars in grey; over the spectrogram it is a thin white line.
  The sound is the recording at one gain, which brings its loudest sample to 1.5 dB below full
  scale, with no compression, encoded as AAC at 256 kbit/s unless `bitrate:` gives another count.
  ffmpeg joins the picture and the sound, so it has to be installed.
  """

  alias Mx.{Audio, Spectrogram, Waveform}
  alias Mx.Engine.Mxs.Native

  @peak -1.5
  @bitrate 256
  @width 1500
  @limit 10_000_000

  @doc """
  Writes the video of the recording at `path` to `out`, with `picture:`, `bitrate:` and `force:`,
  and returns `{:ok, seconds, bytes}`, the video's length and size, or `{:error, message}`.
  """
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    id = System.unique_integer([:positive])
    tmp = System.tmp_dir!()
    pictures = for name <- ["played", "ahead"], do: Path.join(tmp, "mx-video-#{id}-#{name}.png")

    try do
      with {:ok, ffmpeg} <- ffmpeg(),
           :ok <- check(out, Keyword.get(opts, :force, false)),
           {:ok, format, data} <- Audio.raw(path),
           {:ok, inputs, filter} <-
             opts
             |> Keyword.get(:picture, :waveform)
             |> draw(path, pictures, seconds(format, data)),
           sound = [path, gain(format, data), Keyword.get(opts, :bitrate, @bitrate)],
           :ok <- encode(ffmpeg, inputs, filter, sound, seconds(format, data), out) do
        {:ok, seconds(format, data), File.stat!(out).size}
      end
    after
      Enum.each(pictures, &File.rm/1)
    end
  end

  @doc """
  The line that reports a video's length and size, and a warning when the video is over the 10 MB
  GitHub allows for a video on its free plan, or nil.
  """
  def report(out, seconds, bytes)
      when is_binary(out) and is_number(seconds) and is_integer(bytes) do
    length = :erlang.float_to_binary(seconds / 1, decimals: 1)
    size = :erlang.float_to_binary(bytes / 1_000_000, decimals: 1)

    warning =
      "#{out} is over the 10 MB GitHub allows for a video on its free plan; a lower --bitrate makes it smaller"

    {"Wrote #{out}, #{length} seconds and #{size} MB", if(bytes > @limit, do: warning)}
  end

  defp ffmpeg do
    case System.find_executable("ffmpeg") do
      nil ->
        {:error,
         "a video needs ffmpeg to join the picture and the sound, and it is not installed"}

      program ->
        {:ok, program}
    end
  end

  defp check(out, force) do
    if File.exists?(out) and not force do
      {:error, "#{out} exists; give --force to write over it"}
    else
      :ok
    end
  end

  defp seconds(%{rate: rate, channels: channels, bits: bits}, data) do
    max(div(byte_size(data), div(bits, 8) * channels) / rate, 0.1)
  end

  # The gain in dB that brings the recording's loudest sample to 1.5 dB below full scale.
  defp gain(%{channels: channels, bits: bits, kind: kind}, data) do
    case Native.levels(data, {Atom.to_string(kind), bits, channels}, 1) do
      {peak, _levels} when peak > 0 -> @peak - 20 * :math.log10(peak)
      _silent -> 0.0
    end
  end

  # The frames a second at which the playhead moves a pixel or less between frames, from 10 to 30.
  defp rate(travel, seconds), do: travel |> Kernel./(seconds) |> ceil() |> max(10) |> min(30)

  defp draw(:waveform, path, [played, ahead], seconds) do
    with :ok <- Waveform.write(path, played, colour: :amber),
         :ok <- Waveform.write(path, ahead) do
      {left, right} = Waveform.span()
      travel = right - left
      rate = rate(travel, seconds)
      last = seconds - 1 / rate

      filter =
        "[0:v]format=gbrp[played];[1:v]format=gbrp[ahead];" <>
          "[played][ahead]blend=all_expr='if(lt(X,#{left}+min(T/#{last},1)*#{travel}),A,B)',format=yuv420p[v]"

      inputs = [
        "-loop",
        "1",
        "-framerate",
        "#{rate}",
        "-i",
        played,
        "-loop",
        "1",
        "-framerate",
        "#{rate}",
        "-i",
        ahead
      ]

      {:ok, {inputs, ~w(-preset slow -crf 18), rate}, filter}
    end
  end

  defp draw(:spectrogram, path, [picture, _unused], seconds) do
    with :ok <- Spectrogram.stack([path], picture, width: @width, second_lines: false) do
      travel = @width - 2
      rate = rate(travel, seconds)
      last = seconds - 1 / rate
      line = "color=c=white@0.9:s=2x480:r=#{rate}"
      filter = "[0:v][1:v]overlay=x='min(t/#{last},1)*#{travel}':y=0,format=yuv420p[v]"
      inputs = ["-loop", "1", "-framerate", "#{rate}", "-i", picture, "-f", "lavfi", "-i", line]
      {:ok, {inputs, ~w(-preset slow -crf 26 -tune stillimage), rate}, filter}
    end
  end

  defp encode(ffmpeg, {inputs, video, _rate}, filter, [path, gain, bitrate], seconds, out) do
    filter = filter <> ";[2:a]volume=#{gain}dB[a]"

    args =
      ~w(-v error -y) ++
        inputs ++
        ["-i", path, "-filter_complex", filter, "-map", "[v]", "-map", "[a]", "-c:v", "libx264"] ++
        video ++
        ["-c:a", "aac", "-b:a", "#{bitrate}k", "-t", "#{seconds}", "-movflags", "+faststart", out]

    case System.cmd(ffmpeg, args, stderr_to_stdout: true) do
      {_log, 0} ->
        :ok

      {log, _status} ->
        File.rm(out)
        {:error, "ffmpeg could not make the video: #{String.trim(log)}"}
    end
  end
end
