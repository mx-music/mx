defmodule Mx.PNG do
  @moduledoc "Encodes rows of RGB pixels as a PNG image."

  @doc "The PNG image of `height` rows, each `width` pixels of three bytes, from the top."
  def encode(width, height, rows) when is_integer(width) and is_integer(height) do
    header = <<width::32, height::32, 8, 2, 0, 0, 0>>
    data = for row <- rows, do: [<<0>>, row]

    <<137, "PNG", 13, 10, 26, 10>> <>
      chunk("IHDR", header) <> chunk("IDAT", :zlib.compress(data)) <> chunk("IEND", <<>>)
  end

  defp chunk(type, body) do
    <<byte_size(body)::32>> <> type <> body <> <<:erlang.crc32(type <> body)::32>>
  end
end
