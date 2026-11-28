defmodule Mx.Pictures do
  @moduledoc "Reads the pictures and videos the tests of mx's tasks write."

  @doc "The width, height and rows of RGB pixels of a PNG image mx wrote."
  def read_png(path) when is_binary(path) do
    <<137, "PNG", 13, 10, 26, 10, chunks::binary>> = File.read!(path)
    {header, data} = chunks(chunks, nil, <<>>)
    <<width::32, height::32, 8, 2, 0, 0, 0>> = header
    pixels = :zlib.uncompress(data)
    rows = for <<0, row::binary-size(^width * 3) <- pixels>>, do: row
    {width, height, rows}
  end

  @doc "The pixel of a row at a number of pixels across, as `{red, green, blue}`."
  def pixel(row, left) when is_binary(row) and is_integer(left) do
    <<red, green, blue>> = binary_part(row, left * 3, 3)
    {red, green, blue}
  end

  @doc """
  The frames of a video of a width and height, each as rows of RGB pixels, decoded by ffmpeg.
  """
  def frames(path, width, height) when is_binary(path) do
    args = ~w(-v error -i #{path} -f rawvideo -pix_fmt rgb24 -)
    {raw, 0} = System.cmd("ffmpeg", args)

    for <<frame::binary-size(^width * ^height * 3) <- raw>> do
      for <<row::binary-size(^width * 3) <- frame>>, do: row
    end
  end

  defp chunks(
         <<size::32, type::binary-size(4), body::binary-size(size), _crc::32, rest::binary>>,
         header,
         data
       ) do
    case type do
      "IHDR" -> chunks(rest, body, data)
      "IDAT" -> chunks(rest, header, data <> body)
      "IEND" -> {header, data}
      _ -> chunks(rest, header, data)
    end
  end
end
