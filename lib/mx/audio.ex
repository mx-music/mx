defmodule Mx.Audio do
  @moduledoc """
  Reads WAV and AIFF recordings, in mono or stereo, at any sample rate, as one channel of samples from -1 to 1.

  A recording with several channels is read as their average.
  It also writes mono WAV files of 32-bit floats.
  WAV may hold integers of 8 to 32 bits or floats of 32 or 64 bits; AIFF holds big-endian integers, and AIFF-C also little-endian integers and floats.
  """

  @doc "Reads a recording, and returns `{:ok, %{rate: rate, samples: samples}}` or `{:error, \"cannot read PATH\"}`."
  def read(path) when is_binary(path) do
    with {:ok, format, data} <- raw(path) do
      {:ok, %{rate: format.rate, samples: samples(data, format)}}
    end
  end

  @doc "Reads a recording without decoding its samples, and returns `{:ok, format, data}`, the format as its `rate`, `channels`, `bits` and `kind` of sample, or `{:error, \"cannot read PATH\"}`."
  def raw(path) when is_binary(path) do
    with {:ok, binary} <- File.read(path),
         {:ok, format, data} <- parse(binary) do
      {:ok, format, data}
    else
      _ -> {:error, "cannot read #{path}"}
    end
  end

  @doc "Writes samples from -1 to 1 to a mono WAV file of 32-bit floats at a sample rate."
  def write(path, samples, rate) when is_binary(path) and is_list(samples) and is_integer(rate) do
    data = for sample <- samples, into: <<>>, do: <<sample / 1::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, rate::little-32, rate * 4::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
  end

  defp parse(<<"RIFF", _::32, "WAVE", chunks::binary>>) do
    chunks = chunks(chunks, :little)

    with %{"fmt " => fmt, "data" => data} <- chunks,
         <<tag::little-16, channels::little-16, rate::little-32, _::little-32, _::little-16,
           bits::little-16, rest::binary>> <- fmt,
         {:ok, kind} <- wav_kind(tag, bits, rest) do
      {:ok, %{rate: rate, channels: channels, bits: bits, kind: kind}, data}
    else
      _ -> :error
    end
  end

  defp parse(<<"FORM", _::32, form::binary-size(4), chunks::binary>>)
       when form in ["AIFF", "AIFC"] do
    chunks = chunks(chunks, :big)

    with %{"COMM" => comm, "SSND" => <<offset::32, _::32, ssnd::binary>>} <- chunks,
         <<channels::16, _frames::32, bits::16, rate80::binary-size(10), compression::binary>> <-
           comm,
         {:ok, kind} <- aiff_kind(form, compression, bits) do
      <<_::binary-size(^offset), data::binary>> = ssnd
      {:ok, %{rate: extended(rate80), channels: channels, bits: bits, kind: kind}, data}
    else
      _ -> :error
    end
  end

  defp parse(_), do: :error

  defp chunks(<<id::binary-size(4), size::little-32, body::binary>>, :little) do
    chunk(id, size, body, :little)
  end

  defp chunks(<<id::binary-size(4), size::32, body::binary>>, :big) do
    chunk(id, size, body, :big)
  end

  defp chunks(_, _), do: %{}

  defp chunk(id, size, body, endian) do
    size = min(size, byte_size(body))
    padded = min(size + rem(size, 2), byte_size(body))
    <<content::binary-size(^size), _::binary>> = body
    <<_::binary-size(^padded), rest::binary>> = body
    Map.put_new(chunks(rest, endian), id, content)
  end

  defp wav_kind(1, bits, _) when bits in [8, 16, 24, 32] do
    {:ok, if(bits == 8, do: :unsigned, else: :little)}
  end

  defp wav_kind(3, bits, _) when bits in [32, 64], do: {:ok, :float_little}

  defp wav_kind(0xFFFE, bits, <<_::16, _::16, _::32, sub::little-16, _::binary>>) do
    wav_kind(sub, bits, <<>>)
  end

  defp wav_kind(_, _, _), do: :error

  defp aiff_kind("AIFF", _, bits) when bits in [8, 16, 24, 32], do: {:ok, :big}

  defp aiff_kind("AIFC", <<"NONE", _::binary>>, bits) when bits in [8, 16, 24, 32] do
    {:ok, :big}
  end

  defp aiff_kind("AIFC", <<"sowt", _::binary>>, bits) when bits in [16, 24, 32] do
    {:ok, :little}
  end

  defp aiff_kind("AIFC", <<code::binary-size(4), _::binary>>, _) when code in ["fl32", "FL32"] do
    {:ok, :float_big32}
  end

  defp aiff_kind("AIFC", <<code::binary-size(4), _::binary>>, _) when code in ["fl64", "FL64"] do
    {:ok, :float_big64}
  end

  defp aiff_kind(_, _, _), do: :error

  defp decode(:unsigned, _bits, data) do
    for <<value::8 <- data>>, do: (value - 128) / 128
  end

  defp decode(:little, bits, data) do
    for <<value::signed-little-size(^bits) <- data>>, do: value / 2 ** (bits - 1)
  end

  defp decode(:big, bits, data) do
    for <<value::signed-big-size(^bits) <- data>>, do: value / 2 ** (bits - 1)
  end

  defp decode(:float_little, bits, data) do
    for <<value::float-little-size(^bits) <- data>>, do: value
  end

  defp decode(:float_big32, _bits, data) do
    for <<value::float-big-32 <- data>>, do: value
  end

  defp decode(:float_big64, _bits, data) do
    for <<value::float-big-64 <- data>>, do: value
  end

  # An 80-bit IEEE extended float, as AIFF writes its sample rate.
  defp extended(<<_sign::1, exponent::15, mantissa::64>>) do
    round(mantissa * 2 ** (exponent - 16_383 - 63))
  end

  defp samples(data, %{channels: channels, bits: bits, kind: kind}) do
    values = decode(kind, bits, data)

    if channels == 1 do
      values
    else
      frames = Enum.chunk_every(values, channels, channels, :discard)
      for frame <- frames, do: Enum.sum(frame) / channels
    end
  end
end
