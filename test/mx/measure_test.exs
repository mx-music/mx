defmodule Mx.MeasureTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  alias Mx.Measure

  @moduletag :tmp_dir

  test "splits a file of notes a semitone apart and finds each pitch", ctx do
    path =
      write_wav(
        ctx,
        "run.wav",
        48_000,
        Enum.flat_map(0..2, &tone(110 * 2 ** (&1 / 12), 48_000, 3))
      )

    assert {:ok, notes} = Measure.file(path, 45)
    assert Enum.map(notes, & &1.note) == [45, 46, 47]

    for {note, index} <- Enum.with_index(notes) do
      assert_in_delta note.pitch / (110 * 2 ** (index / 12)), 1, 0.002
    end
  end

  test "a harmonic that fades 60 dB in 3 seconds measures 3 seconds, at its level", ctx do
    path = write_wav(ctx, "note.wav", 48_000, tone(220, 48_000, 4))
    {:ok, notes} = Measure.file(path, 57)

    for %{fade: fade} <- Measure.bands(notes), do: assert_in_delta(fade, 3, 0.3)

    [first, second | _] = hd(notes).harmonics
    assert_in_delta second.level - first.level, -6.02, 0.5
    assert_in_delta second.freq, 440, 2
  end

  test "bands give levels against the fundamental of the lowest note", ctx do
    path = write_wav(ctx, "note.wav", 48_000, tone(110, 48_000, 4))
    {:ok, notes} = Measure.file(path, 45)
    bands = notes |> Measure.bands() |> Map.new(&{&1.band, &1})

    assert_in_delta bands[{80, 160}].level, 0, 0.5
    assert_in_delta bands[{160, 250}].level, -6.02, 0.5
  end

  test "finds how far the harmonics are stretched sharp", ctx do
    path = write_wav(ctx, "stiff.wav", 48_000, tone(110, 48_000, 4, stretch: 1.0e-4))
    {:ok, [note]} = Measure.file(path, 45)
    assert_in_delta note.stretch / 1.0e-4, 1, 0.3
  end

  test "ignores rumble below the file's lowest note", ctx do
    clean = write_wav(ctx, "clean.wav", 48_000, tone(110, 48_000, 4))
    rumble = write_wav(ctx, "rumble.wav", 48_000, tone(110, 48_000, 4, rumble: 0.5))
    {:ok, clean} = Measure.file(clean, 45)
    {:ok, rumble} = Measure.file(rumble, 45)
    assert [_] = rumble

    clean
    |> Measure.bands()
    |> Enum.zip(Measure.bands(rumble))
    |> Enum.each(fn {clean_band, rumble_band} ->
      assert clean_band.band == rumble_band.band
      assert_in_delta clean_band.level, rumble_band.level, 1
      assert_in_delta clean_band.fade / rumble_band.fade, 1, 0.1
    end)
  end

  test "a stereo AIFF at 44.1 kHz and a mono WAV at 48 kHz measure the same", ctx do
    wav = write_wav(ctx, "note.wav", 48_000, tone(196, 48_000, 4))
    note = tone(196, 44_100, 4)
    aiff = write_aiff(ctx, "note.aif", 44_100, Enum.zip(note, note))
    {:ok, wav} = Measure.file(wav, 55)
    {:ok, aiff} = Measure.file(aiff, 55)

    wav
    |> Measure.bands()
    |> Enum.zip(Measure.bands(aiff))
    |> Enum.each(fn {wav_band, aiff_band} ->
      assert wav_band.band == aiff_band.band
      assert_in_delta wav_band.level, aiff_band.level, 1
      assert_in_delta wav_band.fade / aiff_band.fade, 1, 0.1
    end)
  end

  test "WAVs of 16, 24 and 32-bit integers measure as one of floats does", ctx do
    note = tone(196, 48_000, 4)
    {:ok, [float]} = Measure.file(write_wav(ctx, "float.wav", 48_000, note), 55)

    for bits <- [16, 24, 32] do
      {:ok, [integer]} = Measure.file(write_pcm(ctx, "#{bits}.wav", 48_000, bits, note), 55)
      assert_in_delta integer.pitch, float.pitch, 0.01

      for {one, other} <- Enum.zip(integer.harmonics, float.harmonics) do
        assert_in_delta one.level, other.level, 0.1
      end
    end
  end

  test "refuses a file it cannot read, and a file with no notes, naming the path", ctx do
    missing = Path.join(ctx.tmp_dir, "missing.wav")
    assert Measure.file(missing, 45) == {:error, "cannot read #{missing}"}

    text = Path.join(ctx.tmp_dir, "text.wav")
    File.write!(text, "not audio")
    assert Measure.file(text, 45) == {:error, "cannot read #{text}"}

    silent = write_wav(ctx, "silent.wav", 48_000, List.duplicate(0.0, 48_000))
    assert Measure.file(silent, 45) == {:error, "found no notes in #{silent}"}
  end

  describe "partials/2" do
    test "follows each harmonic and a bell partial between them, with how each falls", ctx do
      path = write_wav(ctx, "struck.wav", 16_000, struck(16_000))
      assert {:ok, %{pitch: pitch, partials: partials}} = Measure.partials(path, 64)
      assert_in_delta pitch, 329.63, 0.5

      for number <- 1..6 do
        %{fall: fall} = Enum.find(partials, &(&1.harmonic == number))
        assert_in_delta fall, -10 * number, 2, "harmonic #{number} falls #{fall} dB a second"
      end

      bell =
        Enum.find(partials, &(&1.harmonic == 0 and &1.freq / pitch > 7 and &1.freq / pitch < 7.7))

      assert_in_delta bell.freq / pitch, 7.35, 0.01
      # The bell falls 1.4 dB over the first 20 ms its level is read from.
      assert_in_delta bell.level, -30, 1.5
      assert_in_delta bell.fall, -70, 5
    end

    test "leaves out a steady line with no strike and no fall", ctx do
      path = write_wav(ctx, "struck.wav", 16_000, struck(16_000, line: 4108))
      assert {:ok, %{partials: partials, left_out: [line]}} = Measure.partials(path, 64)
      assert_in_delta line.freq, 4108, 1
      refute Enum.any?(partials, &(abs(&1.freq - 4108) < 10))
    end

    test "names a file it cannot read", ctx do
      text = Path.join(ctx.tmp_dir, "note.txt")
      File.write!(text, "not audio")
      assert Measure.partials(text, 64) == {:error, "cannot read #{text}"}
    end
  end

  # E4 struck 0.1 seconds in, rising over 2 ms, and held three seconds, over a noise floor 100 dB
  # down: six harmonics at 1/number of the first, each falling 10 times its number in dB a second,
  # and a bell at 7.35 times the note, 30 dB down, falling 70 dB a second; with a steady line 80
  # dB down at `line` Hz from the first sample when given.
  defp struck(rate, opts \\ []) do
    :rand.seed(:exsss, {1, 2, 3})
    f0 = 329.63
    line = opts[:line]

    for index <- 0..round(3.1 * rate - 1) do
      at = index / rate
      time = max(at - 0.1, 0)
      wave = fn freq -> :math.sin(2 * :math.pi() * freq * time) end
      struck = (1 - :math.cos(:math.pi() * min(time / 0.002, 1))) / 2

      harmonics =
        Enum.sum(for number <- 1..6, do: wave.(f0 * number) / number * 10 ** (-number * time / 2))

      bell = wave.(f0 * 7.35) * 10 ** ((-30 - 70 * time) / 20)
      steady = if line, do: :math.sin(2 * :math.pi() * line * at) * 1.0e-4, else: 0
      noise = (:rand.uniform() - 0.5) * 2.0e-5
      0.3 * (struck * (harmonics + bell) + steady) + noise
    end
  end

  # Twelve harmonics at 1/number of the first, each fading 60 dB over fade seconds, stretched
  # sharp by a stiffness.
  defp tone(f0, rate, seconds, opts \\ []) do
    fade = Keyword.get(opts, :fade, 3)
    stretch = Keyword.get(opts, :stretch, 0)
    rumble = Keyword.get(opts, :rumble, 0)

    freqs =
      for number <- 1..12, do: {number, f0 * number * :math.sqrt(1 + stretch * number * number)}

    for index <- 0..(round(seconds * rate) - 1) do
      time = index / rate
      decay = 10 ** (-3 * time / fade)

      sum =
        Enum.sum(
          for {number, freq} <- freqs, do: :math.sin(2 * :math.pi() * freq * time) / number
        )

      0.1 * sum * decay + rumble * :math.sin(2 * :math.pi() * 40 * time)
    end
  end

  defp write_wav(ctx, name, rate, samples) do
    path = Path.join(ctx.tmp_dir, name)
    data = for sample <- samples, into: <<>>, do: <<sample::float-little-32>>

    fmt =
      <<3::little-16, 1::little-16, rate::little-32, rate * 4::little-32, 4::little-16,
        32::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end

  defp write_pcm(ctx, name, rate, bits, samples) do
    path = Path.join(ctx.tmp_dir, name)
    top = 2 ** (bits - 1) - 1

    data =
      for sample <- samples, into: <<>>, do: <<round(sample * top)::signed-little-size(bits)>>

    bytes = div(bits, 8)

    fmt =
      <<1::little-16, 1::little-16, rate::little-32, rate * bytes::little-32, bytes::little-16,
        bits::little-16>>

    body =
      "WAVE" <>
        "fmt " <> <<16::little-32>> <> fmt <> "data" <> <<byte_size(data)::little-32>> <> data

    File.write!(path, "RIFF" <> <<byte_size(body)::little-32>> <> body)
    path
  end

  defp write_aiff(ctx, name, rate, pairs) do
    path = Path.join(ctx.tmp_dir, name)

    data =
      for {left, right} <- pairs,
          into: <<>>,
          do: <<round(left * 32_767)::signed-16, round(right * 32_767)::signed-16>>

    exponent = floor(:math.log2(rate))
    rate80 = <<16_383 + exponent::16, Bitwise.bsl(rate, 63 - exponent)::64>>
    comm = <<2::16, length(pairs)::32, 16::16>> <> rate80
    ssnd = <<0::32, 0::32>> <> data
    chunks = "COMM" <> <<18::32>> <> comm <> "SSND" <> <<byte_size(ssnd)::32>> <> ssnd
    File.write!(path, "FORM" <> <<byte_size(chunks) + 4::32>> <> "AIFF" <> chunks)
    path
  end
end
