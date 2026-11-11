defmodule Mix.Tasks.Mx.SpectrogramTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Spectrogram

  @moduletag :tmp_dir

  test "draws a recording with octaves up the side and seconds across", ctx do
    low = write_wav(ctx, "a4.wav", sine(440, 2))
    high = write_wav(ctx, "a5.wav", sine(880, 4))

    assert capture_io(fn -> Spectrogram.run([low]) end) =~
             "Wrote #{ctx.tmp_dir}/a4.png"

    capture_io(fn ->
      Spectrogram.run([high, "--out", Path.join(ctx.tmp_dir, "high.png")])
    end)

    {low_width, height, low_rows} = read_png(Path.join(ctx.tmp_dir, "a4.png"))
    {high_width, ^height, high_rows} = read_png(Path.join(ctx.tmp_dir, "high.png"))

    assert high_width == 2 * low_width
    assert brightest(high_rows, div(high_width, 2)) < brightest(low_rows, div(low_width, 2))

    assert brightest(low_rows, div(low_width, 2)) - brightest(high_rows, div(high_width, 2)) ==
             div(height, 10)
  end

  test "refuses a file it cannot read, naming it", ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")

    assert_raise Mix.Error, "cannot read #{missing}", fn ->
      Spectrogram.run([missing])
    end
  end

  # The row, counted from the top, whose pixel in a column is brightest.
  defp brightest(rows, column) do
    rows
    |> Enum.with_index()
    |> Enum.max_by(fn {row, _} ->
      row |> binary_part(column * 3, 3) |> :binary.bin_to_list() |> Enum.sum()
    end)
    |> elem(1)
  end

  defp read_png(path) do
    <<137, "PNG", 13, 10, 26, 10, chunks::binary>> = File.read!(path)
    {header, data} = png_chunks(chunks, nil, <<>>)
    <<width::32, height::32, 8, 2, 0, 0, 0>> = header
    pixels = :zlib.uncompress(data)
    rows = for <<0, row::binary-size(^width * 3) <- pixels>>, do: row
    {width, height, rows}
  end

  defp png_chunks(
         <<size::32, type::binary-size(4), body::binary-size(size), _crc::32, rest::binary>>,
         header,
         data
       ) do
    case type do
      "IHDR" -> png_chunks(rest, body, data)
      "IDAT" -> png_chunks(rest, header, data <> body)
      "IEND" -> {header, data}
      _ -> png_chunks(rest, header, data)
    end
  end

  defp sine(hz, seconds) do
    for index <- 0..(seconds * 48_000 - 1),
        do: 0.5 * :math.sin(2 * :math.pi() * hz * index / 48_000)
  end

  defp write_wav(ctx, name, samples) do
    path = Path.join(ctx.tmp_dir, name)
    data = for sample <- samples, into: <<>>, do: <<sample::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, 48_000::little-32, 192_000::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end
end
