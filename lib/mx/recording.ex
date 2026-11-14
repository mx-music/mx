defmodule Mx.Recording do
  @moduledoc """
  Checks where a session can be recorded, and reads the length, peak and clips of a recording.

  The engine writes the recording itself, so a path it cannot write is refused before playing starts.
  mxs records 32-bit floats, which keep a sound louder than full scale, and a sample at or beyond full scale counts as at full scale.
  Each stretch of frames with a sample at full scale in either channel counts as one clip.
  """

  @full_scale 8_388_608

  @doc "Checks a recording can be written to a path: `:ok`, or `{:error, message}` naming it."
  def check(path, force) when is_binary(path) and is_boolean(force) do
    dir = Path.dirname(path)

    cond do
      File.exists?(path) and not force ->
        {:error, "#{path} already exists; give --force to record over it"}

      not File.dir?(dir) ->
        {:error, "cannot record to #{path}: its folder does not exist"}

      true ->
        writable(path)
    end
  end

  defp writable(path) do
    existed = File.exists?(path)

    case File.open(path, [:append]) do
      {:ok, file} ->
        File.close(file)
        if not existed, do: File.rm(path)
        :ok

      {:error, reason} ->
        reason = :file.format_error(reason)
        {:error, "cannot record to #{path}: #{reason}"}
    end
  end

  @doc "The length of a WAV recording in seconds."
  def seconds(path) when is_binary(path) do
    %{rate: rate, frames: frames} = read_wav(path)
    frames / rate
  end

  @doc "The channels, sample rate and number of frames of a WAV file."
  def read_wav(path) when is_binary(path) do
    %{channels: channels, rate: rate, block_align: block_align, data: data} = wav(path)
    %{channels: channels, rate: rate, frames: div(byte_size(data), block_align)}
  end

  @doc "The peak of a 24-bit or 32-bit float WAV recording in dB below full scale, or nil when it is silent, with how many times it clipped and the seconds of the first clip."
  def level(path) when is_binary(path) do
    %{channels: channels, rate: rate, bits: bits, data: data} = wav(path)
    kind = if bits == 32, do: :float, else: :int24
    {peak, clips, first} = scan(data, kind, channels, 0, {0, 0, nil, false, false})
    peak = if peak > 0, do: 20 * :math.log10(peak / @full_scale)
    first_clip = if first, do: first / rate
    %{peak: peak, clips: clips, first_clip: first_clip}
  end

  @doc "The lines mx prints after recording: the length and peak, and a warning when the recording clipped."
  def report(path) when is_binary(path) do
    seconds = Float.round(seconds(path), 1)
    %{peak: peak, clips: clips, first_clip: first_clip} = level(path)
    peak = if peak, do: :erlang.float_to_binary(peak, decimals: 1), else: "-inf"
    recorded = "Recorded #{seconds} seconds to #{path}, peaking at #{peak} dB."

    if clips > 0 do
      times = if clips == 1, do: "time", else: "times"
      first = Float.round(first_clip, 1)

      [
        recorded,
        "The recording clipped #{clips} #{times}, first at #{first} seconds. Lower the amp of the loudest loops to record it cleanly."
      ]
    else
      [recorded]
    end
  end

  defp wav(path) do
    <<"RIFF", _::32, "WAVE", chunks::binary>> = File.read!(path)

    <<_format::little-16, channels::little-16, rate::little-32, _::little-32,
      block_align::little-16, bits::little-16, _::binary>> = chunk(chunks, "fmt ")

    data = chunk(chunks, "data")
    %{channels: channels, rate: rate, block_align: block_align, bits: bits, data: data}
  end

  # One pass over the samples: the loudest, and each frame with a sample at full scale that
  # follows one without.
  defp scan(<<sample::little-signed-24, rest::binary>>, :int24, channels, index, acc) do
    full = sample == @full_scale - 1 or sample == -@full_scale
    step(abs(sample), full, rest, :int24, channels, index, acc)
  end

  defp scan(<<x::little-float-32, rest::binary>>, :float, channels, index, acc) do
    step(min(abs(x), 1.0) * @full_scale, abs(x) >= 1.0, rest, :float, channels, index, acc)
  end

  defp scan(_rest, _kind, _channels, _index, {peak, clips, first, _before, _now}) do
    {peak, clips, first}
  end

  defp step(size, full, rest, kind, channels, index, acc) do
    {peak, clips, first, before, now} = acc
    now = now or full
    peak = max(peak, size)

    acc =
      cond do
        rem(index + 1, channels) != 0 -> {peak, clips, first, before, now}
        now and not before -> {peak, clips + 1, first || div(index, channels), true, false}
        true -> {peak, clips, first, now, false}
      end

    scan(rest, kind, channels, index + 1, acc)
  end

  defp chunk(<<id::binary-size(4), size::little-32, body::binary>>, wanted) do
    if id == wanted do
      binary_part(body, 0, min(size, byte_size(body)))
    else
      padded = size + rem(size, 2)
      <<_::binary-size(^padded), rest::binary>> = body
      chunk(rest, wanted)
    end
  end
end
