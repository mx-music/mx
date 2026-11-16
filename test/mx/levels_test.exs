defmodule Mx.LevelsTest do
  use ExUnit.Case, async: true

  alias Mx.{Audio, Levels}
  alias Mx.Engine.Mxs

  @moduletag :tmp_dir
  @rate 48_000

  test "a 440 Hz sine gives 30 rows a second, loudest in its octave and as bright as itself",
       %{tmp_dir: dir} do
    path = sine(dir, 440, 2)
    {:ok, rows} = Levels.rows(path)

    assert length(rows) == 60

    for row <- rows do
      assert loudest_band(row) == {320, 640}
      assert_in_delta row.brightness, 440, 5
    end
  end

  test "a 55 Hz sine is loudest in the octave from 40 to 80 Hz in every row", %{tmp_dir: dir} do
    {:ok, rows} = Levels.rows(sine(dir, 55, 2))

    assert Enum.all?(rows, &(loudest_band(&1) == {40, 80}))
  end

  test "a click in silence shows in the row that covers its second", %{tmp_dir: dir} do
    path = click(dir)

    for per_second <- [5, 100] do
      {:ok, rows} = Levels.rows(path, per_second: per_second)
      [loudest | _] = Enum.sort_by(rows, & &1.level, :desc)

      assert loudest.at <= 1.0 and 1.0 < loudest.at + 1 / per_second
      assert loudest.level == 0
      assert Enum.at(rows, 0).level == -100
    end
  end

  test "a click in silence is one stroke, within 10 ms of its second", %{tmp_dir: dir} do
    {:ok, [stroke]} = Levels.strokes(click(dir))

    assert_in_delta stroke.at, 1.0, 0.01
    assert stroke.level == 0
  end

  @tag :engine
  test "a key struck softly and again harder while it rings gives two strokes, the second louder",
       %{tmp_dir: dir} do
    soft = Mxs.render_note(:piano, [note: 60, vel: 0.3, sustain: 8], 3, nil, [])
    hard = Mxs.render_note(:piano, [note: 60, vel: 0.9, sustain: 8], 2, nil, [])
    rate = Mxs.render_rate()
    second = rate

    samples =
      List.duplicate(0.0, second) ++
        Enum.zip_with(
          soft,
          List.duplicate(0.0, second) ++ hard ++ List.duplicate(0.0, second),
          &(&1 + &2)
        )

    path = Path.join(dir, "twice.wav")
    Audio.write(path, Enum.take(samples, 4 * second), rate)

    assert {:ok, [first, again]} = Levels.strokes(path)
    assert_in_delta first.at, 1.0, 0.01
    assert_in_delta again.at, 2.0, 0.01
    assert again.level == 0 and first.level < -3
  end

  test "reads an AIFF recording and a stereo WAV of 32-bit floats", %{tmp_dir: dir} do
    mono =
      for sample <- 0..(@rate - 1), do: 0.5 * :math.sin(2 * :math.pi() * 440 * sample / @rate)

    stereo = for value <- mono, into: <<>>, do: <<value::float-little-32, value::float-little-32>>
    wav = Path.join(dir, "stereo.wav")
    File.write!(wav, wav_file(stereo, 2, 3, 32))

    aiff_data = for value <- mono, into: <<>>, do: <<round(value * 32_767)::signed-big-16>>
    aiff = Path.join(dir, "mono.aiff")
    File.write!(aiff, aiff_file(aiff_data, length(mono)))

    for path <- [wav, aiff] do
      assert {:ok, rows} = Levels.rows(path)
      assert length(rows) == 30
      assert Enum.all?(rows, &(loudest_band(&1) == {320, 640}))
    end
  end

  test "a file that is not a recording is refused as mix mx.spectrogram refuses it",
       %{tmp_dir: dir} do
    path = Path.join(dir, "notes.txt")
    File.write!(path, "not a recording")

    assert Levels.rows(path) == {:error, "cannot read #{path}"}
    assert Levels.strokes(path) == {:error, "cannot read #{path}"}

    assert Mx.Spectrogram.stack([path], Path.join(dir, "out.png")) ==
             {:error, "cannot read #{path}"}
  end

  test "the same recording always gives the same rows", %{tmp_dir: dir} do
    path = click(dir)
    assert Levels.rows(path) == Levels.rows(path)
  end

  defp loudest_band(row) do
    {_level, band} = row.bands |> Enum.zip(Levels.bands()) |> Enum.max_by(&elem(&1, 0))
    band
  end

  defp sine(dir, hz, seconds) do
    path = Path.join(dir, "sine_#{hz}.wav")

    samples =
      for sample <- 0..(seconds * @rate - 1),
          do: 0.5 * :math.sin(2 * :math.pi() * hz * sample / @rate)

    Audio.write(path, samples, @rate)
    path
  end

  defp click(dir) do
    path = Path.join(dir, "click.wav")
    width = div(@rate, 100)

    burst =
      for sample <- 0..(width - 1), do: 0.8 * :math.sin(2 * :math.pi() * 1000 * sample / @rate)

    samples = List.duplicate(0.0, @rate) ++ burst ++ List.duplicate(0.0, @rate - width)

    Audio.write(path, samples, @rate)
    path
  end

  defp wav_file(data, channels, format, bits) do
    block = channels * div(bits, 8)

    fmt =
      <<format::little-16, channels::little-16, @rate::little-32, @rate * block::little-32,
        block::little-16, bits::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    "RIFF" <> <<byte_size(body)::little-32>> <> body
  end

  # An AIFF's rate is an 80-bit extended float: 48,000 is 2^15 times 1.46484375.
  defp aiff_file(data, frames) do
    rate = <<0x400E::16, 0xBB80_0000_0000_0000::64>>
    comm = "COMM" <> <<18::32, 1::16, frames::32, 16::16>> <> rate
    ssnd = "SSND" <> <<byte_size(data) + 8::32, 0::32, 0::32>> <> data
    body = "AIFF" <> comm <> ssnd
    "FORM" <> <<byte_size(body)::32>> <> body
  end
end
