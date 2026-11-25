defmodule Mx.OSC do
  @moduledoc """
  Encodes and decodes the OSC messages and bundles mx exchanges with other programs.

  Integers are sent as int32, floats as float32 and strings as OSC strings.
  Bundle times are Unix microseconds, converted to and from NTP time tags.
  """

  @ntp_offset 2_208_988_800
  @fraction 4_294_967_296

  @doc ~S"""
  Encodes an OSC message to an address with its arguments.

  ## Examples

      iex> message("/status", []) == "/status\0,\0\0\0"
      true

      iex> message("/s_new", ["beep", -1, 0.5]) ==
      ...>   "/s_new\0\0,sif\0\0\0\0beep\0\0\0\0" <> <<-1::signed-32, 0.5::float-32>>
      true
  """
  def message(address, args) when is_binary(address) and is_list(args) do
    tags = Enum.map_join(args, &tag/1)
    string(address) <> string("," <> tags) <> Enum.map_join(args, &arg/1)
  end

  @doc """
  Encodes encoded messages into a bundle stamped with a Unix time in microseconds.

  ## Examples

      iex> bundle = bundle(1_000_000_000_250_000, [message("/status", [])])
      iex> decode(bundle)
      {:bundle, 1_000_000_000_250_000, [{"/status", []}]}
  """
  def bundle(unix_us, messages) when is_integer(unix_us) and is_list(messages) do
    seconds = div(unix_us, 1_000_000) + @ntp_offset
    fraction = div(rem(unix_us, 1_000_000) * @fraction, 1_000_000)
    elements = Enum.map_join(messages, fn message -> <<byte_size(message)::32>> <> message end)
    string("#bundle") <> <<seconds::32, fraction::32>> <> elements
  end

  @doc """
  Decodes a message as `{address, args}`, or a bundle as `{:bundle, unix_us, elements}`.

  ## Examples

      iex> decode(message("/s_new", ["beep", -1, 0.5]))
      {"/s_new", ["beep", -1, 0.5]}

      iex> decode(bundle(0, [message("/n_free", [1001])]))
      {:bundle, 0, [{"/n_free", [1001]}]}
  """
  def decode(<<"#bundle\0", seconds::32, fraction::32, elements::binary>>) do
    unix_us = (seconds - @ntp_offset) * 1_000_000 + round(fraction * 1_000_000 / @fraction)
    {:bundle, unix_us, decode_elements(elements)}
  end

  def decode(packet) when is_binary(packet) do
    {address, rest} = read_string(packet)
    {"," <> tags, rest} = read_string(rest)
    args = tags |> String.graphemes() |> decode_args(rest)
    {address, args}
  end

  defp decode_elements(<<>>), do: []

  defp decode_elements(<<size::32, element::binary-size(size), rest::binary>>) do
    [decode(element) | decode_elements(rest)]
  end

  defp decode_args([], _), do: []

  defp decode_args(["i" | tags], <<i::signed-32, rest::binary>>) do
    [i | decode_args(tags, rest)]
  end

  defp decode_args(["f" | tags], <<f::float-32, rest::binary>>), do: [f | decode_args(tags, rest)]
  defp decode_args(["d" | tags], <<d::float-64, rest::binary>>), do: [d | decode_args(tags, rest)]

  defp decode_args(["s" | tags], rest) do
    {s, rest} = read_string(rest)
    [s | decode_args(tags, rest)]
  end

  defp read_string(binary) do
    [s, _] = :binary.split(binary, <<0>>)
    size = byte_size(string(s))
    <<_::binary-size(^size), rest::binary>> = binary
    {s, rest}
  end

  defp tag(arg) when is_integer(arg), do: "i"
  defp tag(arg) when is_float(arg), do: "f"
  defp tag(arg) when is_binary(arg), do: "s"

  defp arg(arg) when is_integer(arg), do: <<arg::signed-32>>
  defp arg(arg) when is_float(arg), do: <<arg::float-32>>
  defp arg(arg) when is_binary(arg), do: string(arg)

  defp string(text), do: text <> :binary.copy(<<0>>, 4 - rem(byte_size(text), 4))
end
