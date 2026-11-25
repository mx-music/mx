defmodule Mix.Tasks.Mx.SpectrogramTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import Bitwise
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

  test "draws several recordings one above another, a stretch of each, at the pixels a second given",
       ctx do
    low = write_wav(ctx, "a4.wav", sine(440, 2))
    high = write_wav(ctx, "a5.wav", sine(880, 4))
    capture_io(fn -> Spectrogram.run([low]) end)
    {_width, height, alone} = read_png(Path.join(ctx.tmp_dir, "a4.png"))

    args = [low, high, "--from", "0.5", "--seconds", "1", "--per-second", "40", "--window", "20"]
    assert capture_io(fn -> Spectrogram.run(args) end) =~ "Wrote #{ctx.tmp_dir}/a4.png"
    {width, stacked, rows} = read_png(Path.join(ctx.tmp_dir, "a4.png"))

    assert width == 40
    assert stacked == 2 * height
    {above, below} = Enum.split(rows, height)
    assert_in_delta brightest(above, 20), brightest(alone, 100), 1
    assert_in_delta brightest(above, 20) - brightest(below, 20), div(height, 10), 1
  end

  test "draws the picture the task drew when Elixir worked out its columns, to a step of 255",
       ctx do
    sound =
      for index <- 0..(round(0.6 * 48_000) - 1) do
        at = index / 48_000

        0.4 * :math.exp(-3 * at) * :math.sin(2 * :math.pi() * 440 * at) +
          0.2 * :math.sin(2 * :math.pi() * 3000 * at)
      end

    path = write_wav(ctx, "two.wav", sound)
    args = [path, "--from", "0.1", "--seconds", "0.4", "--per-second", "200", "--window", "10"]
    capture_io(fn -> Spectrogram.run(args) end)

    {width, height, rows} = read_png(Path.join(ctx.tmp_dir, "two.png"))
    assert {^width, ^height, before} = read_png("test/support/spectrograms/in_elixir.png")

    drawn = rows |> IO.iodata_to_binary() |> :binary.bin_to_list()
    expected = before |> IO.iodata_to_binary() |> :binary.bin_to_list()
    assert drawn |> Enum.zip_with(expected, &abs(&1 - &2)) |> Enum.max() <= 1
  end

  test "reads AIFF and stereo recordings as it reads a mono WAV", ctx do
    samples = sine(440, 1)
    capture_io(fn -> Spectrogram.run([write_wav(ctx, "mono.wav", samples)]) end)
    expected = read_png(Path.join(ctx.tmp_dir, "mono.png"))

    stereo =
      for sample <- samples, into: <<>>, do: <<sample::float-little-32, sample::float-little-32>>

    fmt =
      <<3::little-16, 2::little-16, 48_000::little-32, 384_000::little-32, 8::little-16,
        32::little-16>>

    wav =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(stereo)::little-32>> <> stereo

    ctx.tmp_dir
    |> Path.join("stereo.wav")
    |> File.write!("RIFF" <> <<byte_size(wav)::little-32>> <> wav)

    floats = for sample <- samples, into: <<>>, do: <<sample::float-big-32>>
    # 48,000 as the 80-bit float AIFF writes its rate in.
    comm = <<1::16, length(samples)::32, 32::16, 0x400E::16, 48_000 <<< 48::64, "fl32", 0, 0>>
    ssnd = <<0::32, 0::32>> <> floats

    aiff =
      "AIFC" <>
        "COMM" <> <<byte_size(comm)::32>> <> comm <> "SSND" <> <<byte_size(ssnd)::32>> <> ssnd

    ctx.tmp_dir |> Path.join("big.aifc") |> File.write!("FORM" <> <<byte_size(aiff)::32>> <> aiff)

    for name <- ["stereo", "big"] do
      [path] = ctx.tmp_dir |> Path.join(name <> ".*") |> Path.wildcard()
      capture_io(fn -> Spectrogram.run([path]) end)
      assert read_png(Path.join(ctx.tmp_dir, name <> ".png")) == expected
    end
  end

  test "--no-seconds leaves out the line at each second and keeps the line at each octave", ctx do
    path = write_wav(ctx, "quiet.wav", sine(440, 2))
    capture_io(fn -> Spectrogram.run([path]) end)
    {_, height, lined} = read_png(Path.join(ctx.tmp_dir, "quiet.png"))
    capture_io(fn -> Spectrogram.run([path, "--no-seconds"]) end)
    {200, ^height, bare} = read_png(Path.join(ctx.tmp_dir, "quiet.png"))

    line = <<60, 60, 60>>
    assert binary_part(Enum.at(lined, 10), 100 * 3, 3) == line
    assert binary_part(Enum.at(bare, 10), 100 * 3, 3) == <<0, 0, 0>>
    assert binary_part(Enum.at(bare, 10), 0, 3) == <<0, 0, 0>>
    assert Enum.at(bare, 47) == :binary.copy(line, 200)
  end

  test "--width draws the stretch that many pixels wide, and shows a click shorter than the sound between two columns",
       ctx do
    click = Enum.take(sine(2000, 1), 480)
    before = List.duplicate(0.0, round(5.15 * 48_000))
    path = write_wav(ctx, "click.wav", before ++ click ++ List.duplicate(0.0, 5 * 48_000))
    capture_io(fn -> Spectrogram.run([path, "--width", "50"]) end)
    {width, _height, rows} = read_png(Path.join(ctx.tmp_dir, "click.png"))

    assert width == 50
    lit = for row <- rows, column <- 0..49, binary_part(row, column * 3, 1) == <<255>>, do: column
    assert Enum.uniq(lit) == [25]
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
