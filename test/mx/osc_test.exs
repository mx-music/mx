defmodule Mx.OSCTest do
  use ExUnit.Case, async: true

  alias Mx.OSC

  doctest Mx.OSC, import: true

  test "encodes a message with integer, float and string arguments, padded to four bytes" do
    assert OSC.message("/s_new", ["beep", -1, 0.5]) ==
             "/s_new\0\0" <>
               ",sif\0\0\0\0" <> "beep\0\0\0\0" <> <<-1::signed-32>> <> <<0.5::float-32>>
  end

  test "encodes a message without arguments" do
    assert OSC.message("/status", []) == "/status\0" <> ",\0\0\0"
  end

  test "encodes a bundle with its time as an NTP time tag" do
    message = OSC.message("/status", [])
    unix_us = 1_000_000_000_250_000

    <<"#bundle\0", seconds::32, fraction::32, size::32, rest::binary>> =
      OSC.bundle(unix_us, [message])

    assert seconds == 1_000_000_000 + 2_208_988_800
    assert fraction == div(2 ** 32, 4)
    assert size == byte_size(message)
    assert rest == message
  end

  test "decodes a bundle back into its time and messages" do
    packet = OSC.bundle(1_000_000_000_250_000, [OSC.message("/s_new", ["beep", 3, 1.5])])
    assert OSC.decode(packet) == {:bundle, 1_000_000_000_250_000, [{"/s_new", ["beep", 3, 1.5]}]}
  end

  test "decodes a reply message" do
    assert OSC.decode(OSC.message("/done", ["/d_loadDir"])) == {"/done", ["/d_loadDir"]}
  end

  test "decodes doubles, such as other programs send" do
    packet = "/status.reply\0\0\0" <> ",id\0" <> <<1::32>> <> <<48_000.0::float-64>>
    assert OSC.decode(packet) == {"/status.reply", [1, 48_000.0]}
  end
end
