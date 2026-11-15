defmodule Mix.Tasks.Mx.WaveformTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mx.Pictures, only: [read_png: 1, pixel: 2]

  alias Mix.Tasks.Mx.Waveform

  @moduletag :tmp_dir

  @background {17, 19, 24}
  @grey {74, 80, 96}

  test "draws bars on a dark background, 1500 pixels wide and 150 high", ctx do
    path = write(ctx, "tone.wav", tone(2, fn _ -> 0.5 end))

    assert capture_io(fn -> Waveform.run([path]) end) =~ "Wrote #{ctx.tmp_dir}/tone.png"

    {1500, 150, rows} = read_png(Path.join(ctx.tmp_dir, "tone.png"))
    middle = Enum.at(rows, 75)
    assert pixel(hd(rows), 0) == @background
    assert pixel(middle, 20) == @background
    assert pixel(middle, 40) == @grey
    assert pixel(middle, 41) == @grey
    assert pixel(middle, 42) == @background
    assert pixel(middle, 43) == @grey
    assert pixel(middle, 1457) == @grey
    assert pixel(middle, 1458) == @background
  end

  test "a recording silent for its first half has bars of the least height across the left half",
       ctx do
    path = write(ctx, "late.wav", tone(2, fn at -> if at < 1, do: 0.0, else: 0.5 end))
    capture_io(fn -> Waveform.run([path]) end)
    {_width, _height, rows} = read_png(Path.join(ctx.tmp_dir, "late.png"))

    heights = heights(rows)
    {left, right} = Enum.split(heights, div(length(heights), 2))
    assert Enum.uniq(Enum.drop(left, -1)) == [2]
    assert Enum.min(Enum.drop(right, 1)) > 100
  end

  test "a recording with a crescendo has bars that grow from left to right", ctx do
    path = write(ctx, "louder.wav", tone(2, fn at -> 0.05 + 0.2 * at end))
    capture_io(fn -> Waveform.run([path]) end)
    {_width, _height, rows} = read_png(Path.join(ctx.tmp_dir, "louder.png"))

    tenths = rows |> heights() |> Enum.chunk_every(43, 43, :discard) |> Enum.map(&Enum.sum/1)
    assert tenths == Enum.sort(tenths)
    assert List.last(tenths) > 3 * hd(tenths)
  end

  test "--width, --height and --out give another size and file", ctx do
    path = write(ctx, "tone.wav", tone(1, fn _ -> 0.5 end))
    out = Path.join(ctx.tmp_dir, "small.png")
    capture_io(fn -> Waveform.run([path, "--width", "600", "--height", "80", "--out", out]) end)

    assert {600, 80, _rows} = read_png(out)
  end

  test "refuses a file it cannot read, naming it", ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")
    assert_raise Mix.Error, "cannot read #{missing}", fn -> Waveform.run([missing]) end
  end

  # The pixels down each bar that are not the background, from the left bar.
  defp heights(rows) do
    for left <- 40..1456//3 do
      Enum.count(rows, &(pixel(&1, left) != @background))
    end
  end

  defp tone(seconds, level) do
    for index <- 0..(seconds * 48_000 - 1) do
      at = index / 48_000
      level.(at) * :math.sin(2 * :math.pi() * 440 * at)
    end
  end

  defp write(ctx, name, samples) do
    path = Path.join(ctx.tmp_dir, name)
    Mx.Audio.write(path, samples, 48_000)
    path
  end
end
