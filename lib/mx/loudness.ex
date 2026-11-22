defmodule Mx.Loudness do
  @moduledoc """
  Measures how loud a recording is heard, and scales a recording to a loudness.

  The measure is the integrated loudness of ITU-R BS.1770-4, in LUFS, the one streaming services turn each track by.
  Each channel goes through the recommendation's two filters, a shelf that raises the highs by 4 dB and a high-pass at 38 Hz.
  The recording is then cut into blocks of 400 ms, each starting 100 ms after the one before, and the loudness is that of the mean power of the blocks left by two gates: one drops the blocks under -70 LUFS, and one the blocks more than 10 LU under the loudness of the rest.
  Every channel counts alike, so it is right for mono and stereo.
  """

  alias Mx.Audio

  @block 4
  @absolute_gate -70.0
  @relative_gate -10.0

  @doc "The integrated loudness of a recording in LUFS, or nil when it cannot be read, is shorter than 0.4 seconds, or has no block over -70 LUFS."
  def measure(path) when is_binary(path) do
    with {:ok, %{rate: rate, channels: channels} = format, data} <- Audio.raw(path),
         {:ok, size, decode} <- decoder(format) do
      hop = div(rate, 10)
      filters = filters(rate)

      powers =
        for channel <- 0..(channels - 1)//1 do
          before = channel * size
          rest = (channels - channel - 1) * size

          data
          |> hops(decode, {before, size, rest}, hop, filters)
          |> Enum.chunk_every(@block, 1, :discard)
          |> Enum.map(&(Enum.sum(&1) / (@block * hop)))
        end

      powers |> Enum.zip_with(&Enum.sum/1) |> gated()
    else
      _ -> nil
    end
  end

  @doc "Scales a WAV recording of 32-bit floats by a gain in dB, in place."
  def scale(path, db) when is_binary(path) and is_number(db) do
    {head, data, tail} = split(File.read!(path))
    gain = :math.pow(10, db / 20)
    scaled = for <<x::little-float-32 <- data>>, into: <<>>, do: <<x * gain::little-float-32>>
    File.write!(path, [head, scaled, tail])
  end

  defp gated(blocks) do
    heard = Enum.filter(blocks, &(&1 > 0 and lufs(&1) > @absolute_gate))

    if heard != [] do
      floor = lufs(mean(heard)) + @relative_gate
      lufs(mean(Enum.filter(heard, &(lufs(&1) > floor))))
    end
  end

  defp mean(values), do: Enum.sum(values) / length(values)

  defp lufs(power), do: -0.691 + 10 * :math.log10(power)

  defp decoder(%{kind: :float_little, bits: 32}) do
    {:ok, 4, fn <<x::little-float-32>> -> x end}
  end

  defp decoder(%{kind: :little, bits: bits}) when bits in [16, 24, 32] do
    full = Bitwise.bsl(1, bits - 1)
    {:ok, div(bits, 8), fn <<x::little-signed-size(^bits)>> -> x / full end}
  end

  defp decoder(_format), do: :error

  # The two filters of BS.1770 at a sample rate, each as the five coefficients of a biquad.
  defp filters(rate) do
    warped = :math.tan(:math.pi() * 1681.974450955533 / rate)
    quality = 0.7071752369554196
    high = :math.pow(10, 3.999843853973347 / 20)
    band = :math.pow(high, 0.4996667741545416)
    a0 = 1 + warped / quality + warped * warped

    shelf =
      {(high + band * warped / quality + warped * warped) / a0, 2 * (warped * warped - high) / a0,
       (high - band * warped / quality + warped * warped) / a0, 2 * (warped * warped - 1) / a0,
       (1 - warped / quality + warped * warped) / a0}

    warped = :math.tan(:math.pi() * 38.13547087602444 / rate)
    quality = 0.5003270373238773
    a0 = 1 + warped / quality + warped * warped

    {shelf,
     {1.0, -2.0, 1.0, 2 * (warped * warped - 1) / a0,
      (1 - warped / quality + warped * warped) / a0}}
  end

  # The filtered power of one channel summed over each whole stretch of `hop` frames.
  defp hops(data, decode, {before, width, rest} = layout, hop, filters) do
    stretch = hop * (before + width + rest)
    whole = div(byte_size(data), stretch)

    {sums, _state} =
      Enum.map_reduce(0..(whole - 1)//1, {0.0, 0.0, 0.0, 0.0}, fn index, state ->
        sum(binary_part(data, index * stretch, stretch), decode, layout, filters, state, 0.0)
      end)

    sums
  end

  defp sum(<<>>, _decode, _layout, _filters, state, total), do: {total, state}

  defp sum(
         data,
         decode,
         {before, width, rest} = layout,
         filters,
         {shelf1, shelf2, pass1, pass2},
         total
       ) do
    <<_::binary-size(^before), sample::binary-size(^width), _::binary-size(^rest), more::binary>> =
      data

    {{b0, b1, b2, a1, a2}, {c0, c1, c2, d1, d2}} = filters
    input = decode.(sample)
    shelved = b0 * input + shelf1
    shelf1 = b1 * input - a1 * shelved + shelf2
    shelf2 = b2 * input - a2 * shelved
    weighted = c0 * shelved + pass1
    pass1 = c1 * shelved - d1 * weighted + pass2
    pass2 = c2 * shelved - d2 * weighted

    sum(
      more,
      decode,
      layout,
      filters,
      {shelf1, shelf2, pass1, pass2},
      total + weighted * weighted
    )
  end

  defp split(<<"RIFF", size::binary-size(4), "WAVE", chunks::binary>>) do
    {before, data, tail} = data_chunk(chunks, <<>>)
    {["RIFF", size, "WAVE", before], data, tail}
  end

  defp data_chunk(<<"data", size::little-32, body::binary>>, before) do
    size = min(size, byte_size(body))
    <<data::binary-size(^size), tail::binary>> = body
    {before <> "data" <> <<size::little-32>>, data, tail}
  end

  defp data_chunk(<<id::binary-size(4), size::little-32, body::binary>>, before) do
    padded = size + rem(size, 2)
    <<content::binary-size(^padded), rest::binary>> = body
    data_chunk(rest, before <> id <> <<size::little-32>> <> content)
  end
end
