defmodule Mx.WindsTest do
  # The Philharmonia Orchestra's samples, from https://philharmonia.co.uk/resources/sound-samples/, unzipped into the folder MX_PHILHARMONIA names, with Woodwind and Brass in it.
  # They are MP3s, so ffmpeg turns each into a WAV first.
  use ExUnit.Case, async: false

  alias Mx.Engine.Mxs

  @moduletag :engine
  @moduletag :philharmonia
  @moduletag :tmp_dir
  @rate 48_000

  # Each legato phrase as mix mx.hum transcribes it at 60 beats a minute, each note with its seconds.
  @phrases %{
    flute:
      {"Woodwind/flute/flute_C5_phrase_mezzo-forte_legato.mp3",
       ~w(c5 0.25 cs5 0.5 c5 0.25 d5 0.25 b4 0.25 d5 0.25 as4 0.25 d5 0.25 as4 0.25 a4 0.5 ds5 0.25 a4 0.25 gs4 0.25 f4 0.25 gs4 0.25 g4 0.5 g4 0.5 g5 1 g4 1.25)},
    bassoon:
      {"Woodwind/bassoon/bassoon_C3_phrase_mezzo-forte_legato.mp3",
       ~w(c3 0.25 c4 0.25 c3 0.75 b3 0.25 c3 0.25 cs3 0.25 as3 0.5 cs3 0.25 ds3 0.25 a3 0.25 ds3 0.25 e3 0.25 gs3 0.25 e3 0.25 f3 0.25 g3 0.5 f3 0.25 fs3 1.75)},
    tenor_sax:
      {"Woodwind/saxophone/saxophone_D4_phrase_mezzo-forte_legato.mp3",
       ~w(ds4 0.5 e4 0.25 ds4 0.5 f4 0.25 d4 0.5 f4 0.5 cs4 0.25 e4 0.5 cs4 0.25 c4 0.5 fs4 0.25 b3 1 g4 0.25 as3 0.5 a3 0.25 a4 0.5 a3 0.5 as4 1.25 a3 1.25)},
    horn:
      {"Brass/french horn/french-horn_C3_phrase_forte_legato.mp3",
       ~w(b2 0.25 c3 1 c4 1.25 c3 1.25 cs3 1 as3 1.25 cs3 1)},
    trombone:
      {"Brass/trombone/trombone_F3_phrase_mezzo-forte_legato.mp3",
       ~w(f3 0.5 f4 0.25 f3 0.5 fs3 0.25 e4 0.25 fs3 0.5 g3 0.25 ds4 0.25 g3 0.75 cs4 0.25 g3 0.5 gs3 0.25 c4 0.5 gs3 0.25 as3 0.25 c4 0.5 as3 0.25 b3 1.25 b3 0.5)}
  }

  # The phrase's vel: the horn's is played forte, the others mezzo-forte.
  @phrase_vel %{flute: 0.6, bassoon: 0.6, tenor_sax: 0.6, horn: 0.8, trombone: 0.6}

  for {synth, {file, steps}} <- @phrases do
    @synth synth
    @recorded file
    @steps steps

    test "#{synth} slurs the Philharmonia's legato phrase with gaps no longer than 30 percent over the recording's",
         ctx do
      recorded = longest_gap(recording(ctx, @recorded))
      steps = steps(@steps)
      slurred = longest_gap(slurred(ctx, @synth, steps, @phrase_vel[@synth]))

      assert slurred <= recorded * 1.3 + 0.005,
             "slurred gap #{slurred} s against the recording's #{recorded} s"
    end
  end

  test "flute's slurred phrase has no gap, and the same notes played detached have gaps", ctx do
    {_, steps} = @phrases.flute
    steps = steps(steps)
    assert longest_gap(slurred(ctx, :flute, steps, 0.6)) == 0
    assert longest_gap(detached(ctx, :flute, steps, 0.6)) >= 0.04
  end

  # Each wind's long note that swells and fades, with the note it is played on.
  @swells %{
    flute: {"Woodwind/flute/flute_A4_very-long_cresc-decresc_normal.mp3", 69},
    clarinet: {"Woodwind/clarinet/clarinet_D4_very-long_cresc-decresc_normal.mp3", 62},
    bassoon: {"Woodwind/bassoon/bassoon_E3_very-long_cresc-decresc_normal.mp3", 52},
    tenor_sax: {"Woodwind/saxophone/saxophone_D4_very-long_cresc-decresc_normal.mp3", 62},
    horn: {"Brass/french horn/french-horn_C3_very-long_cresc-decresc_normal.mp3", 48},
    trombone: {"Brass/trombone/trombone_E3_very-long_cresc-decresc_normal.mp3", 52},
    tuba: {"Brass/tuba/tuba_C3_very-long_cresc-decresc_normal.mp3", 48}
  }

  for {synth, {file, note}} <- @swells do
    @synth synth
    @recorded file
    @note note

    test "#{synth} swells and fades within 3 dB of the Philharmonia's long note, every half second, with vel following it",
         ctx do
      levels = recording(ctx, @recorded) |> half_seconds()
      peak = Enum.max(levels)
      relative = Enum.map(levels, &(&1 - peak))
      curve = loudness(ctx, @synth, @note)
      {_, loudest} = List.last(curve)
      vels = Enum.map(relative, &vel_at(curve, loudest + &1))
      [first | later] = vels
      seconds = length(vels) * 0.5

      changes =
        later
        |> Enum.with_index(1)
        |> Enum.map(fn {vel, i} -> {i * 0.5 - 0.5, vel: vel, vel_slide: 0.5} end)

      sound =
        Mxs.render_note(
          @synth,
          [note: @note, vel: first, vibrato: 0, sustain: seconds, release: 0.1],
          seconds + 0.5,
          ctx.tmp_dir,
          changes
        )

      ours = sound |> windows(div(@rate, 2), div(@rate, 20)) |> Enum.map(&db/1)
      ours_peak = Enum.max(ours)

      for {{theirs, mine}, index} <- Enum.with_index(Enum.zip(relative, ours)), index > 0 do
        seconds = index * 0.5
        relative_db = mine - ours_peak

        assert_in_delta relative_db,
                        theirs,
                        3,
                        "at #{seconds} s #{relative_db} dB against the recording's #{theirs} dB"
      end
    end
  end

  # The median dip in dB at a slur over the Philharmonia's legato phrases, with a note mid-range to slur from; the clarinet's and oboe's from the bass clarinet's and cor anglais', the trumpet's from the trombone's and horn's.
  # The tuba, whose lowest notes dip 6 dB at most, is left out.
  @dips %{
    clarinet: {-6.0, 62},
    oboe: {-6.7, 69},
    bassoon: {-6.8, 50},
    tenor_sax: {-8.9, 62},
    trumpet: {-13.7, 67},
    trombone: {-14.0, 55},
    horn: {-13.4, 60}
  }

  for {synth, {dip, note}} <- @dips do
    @synth synth
    @dip dip
    @note note

    test "#{synth} dips within 3 dB of the Philharmonia's legato phrases at each slur", ctx do
      steps =
        for step <- [0, 2, 4, 2, 7, 5, 4, 0, -3, 0, 5, 2, 9, 7, 4, 0], do: {@note + step, 0.3}

      sound = slurred(ctx, @synth, steps, 0.6, 0)
      levels = sound |> windows(div(@rate, 200), div(@rate, 100)) |> Enum.map(&db/1)

      dips =
        for slur <- 1..(length(steps) - 1) do
          at = round(slur * 0.3 * 200)
          before = levels |> Enum.slice((at - 40)..(at - 10)) |> median()
          Enum.min(Enum.slice(levels, (at - 16)..(at + 16))) - before
        end

      assert_in_delta median(dips), @dip, 3, "median dip #{median(dips)} dB at #{inspect(dips)}"
    end
  end

  defp median(values), do: Enum.at(Enum.sort(values), div(length(values), 2))

  defp steps(words) do
    words
    |> Enum.chunk_every(2)
    |> Enum.map(fn [name, seconds] ->
      {held, ""} = Float.parse(seconds)
      {Mx.Notes.note(String.to_atom(name)), held}
    end)
  end

  defp slurred(ctx, synth, steps, vel, slide \\ 0.02)

  defp slurred(ctx, synth, [{first, held} | rest], vel, slide) do
    total = held + Enum.sum(Enum.map(rest, &elem(&1, 1)))

    {changes, _} =
      Enum.map_reduce(rest, held, fn {note, seconds}, at ->
        {{at, note: note / 1, note_slide: slide}, at + seconds}
      end)

    Mxs.render_note(
      synth,
      [note: first, vel: vel, sustain: total, release: 0.2],
      total + 0.5,
      ctx.tmp_dir,
      changes
    )
  end

  defp detached(ctx, synth, steps, vel) do
    {sounds, total} =
      Enum.map_reduce(steps, 0.0, fn {note, seconds}, at ->
        sound =
          Mxs.render_note(
            synth,
            [note: note, vel: vel, sustain: max(seconds - 0.1, 0.02), release: 0.08],
            seconds + 0.3,
            ctx.tmp_dir,
            []
          )

        {{round(at * @rate), sound}, at + seconds}
      end)

    length = round((total + 0.5) * @rate)

    sounds
    |> Enum.reduce(:array.new(length, default: 0.0), fn {start, sound}, mixed ->
      sound
      |> Enum.with_index(start)
      |> Enum.reduce(mixed, fn {x, i}, acc ->
        if i < length, do: :array.set(i, :array.get(i, acc) + x, acc), else: acc
      end)
    end)
    |> :array.to_list()
  end

  defp recording(ctx, file) do
    dir =
      System.get_env("MX_PHILHARMONIA") ||
        flunk("set MX_PHILHARMONIA to the folder of the Philharmonia samples")

    ffmpeg =
      System.find_executable("ffmpeg") || flunk("ffmpeg turns the Philharmonia's MP3s into WAVs")

    wav = Path.join(ctx.tmp_dir, Path.basename(file, ".mp3") <> ".wav")
    {_, 0} = System.cmd(ffmpeg, ["-loglevel", "error", "-y", "-i", Path.join(dir, file), wav])
    {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(wav)
    {samples, rate}
  end

  # The longest stretch, in seconds, whose level over 10 ms windows every 5 ms stands more than 20 dB below the loudest, between the first and last windows within 20 dB of it.
  defp longest_gap({samples, rate}), do: longest_gap(samples, rate)
  defp longest_gap(samples), do: longest_gap(samples, @rate)

  defp longest_gap(samples, rate) do
    hop = div(rate, 200)
    levels = samples |> windows(hop, hop * 2) |> Enum.map(&db/1)
    floor = Enum.max(levels) - 20
    first = Enum.find_index(levels, &(&1 > floor))
    last = length(levels) - 1 - Enum.find_index(Enum.reverse(levels), &(&1 > floor))

    longest =
      levels
      |> Enum.slice(first..last)
      |> Enum.chunk_by(&(&1 <= floor))
      |> Enum.filter(fn [level | _] -> level <= floor end)
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)

    longest * hop / rate
  end

  # The level in dB of 50 ms windows every half second, from the first window within 30 dB of the loudest.
  defp half_seconds({samples, rate}) do
    levels = samples |> windows(div(rate, 2), div(rate, 20)) |> Enum.map(&db/1)
    floor = Enum.max(levels) - 30

    levels
    |> Enum.drop_while(&(&1 < floor))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 < floor))
    |> Enum.reverse()
  end

  defp windows(samples, hop, size) when size <= hop do
    samples |> Enum.chunk_every(hop, hop, :discard) |> Enum.map(&Enum.take(&1, size))
  end

  defp windows(samples, hop, size) do
    samples
    |> Enum.chunk_every(hop)
    |> Enum.chunk_every(div(size, hop), 1, :discard)
    |> Enum.map(&List.flatten/1)
  end

  defp db(window) do
    rms = :math.sqrt(Enum.sum(Enum.map(window, &(&1 * &1))) / max(length(window), 1))
    20 * :math.log10(max(rms, 1.0e-9))
  end

  # The synth's level in dB while a note holds, at each of a range of vels.
  defp loudness(ctx, synth, note) do
    [0.02, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    |> Task.async_stream(
      fn vel ->
        sound =
          Mxs.render_note(
            synth,
            [note: note, vel: vel, vibrato: 0, sustain: 1.5],
            1.5,
            ctx.tmp_dir,
            []
          )

        {vel, db(Enum.slice(sound, round(1.0 * @rate), round(0.5 * @rate)))}
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, point} -> point end)
  end

  # The vel whose level is the one given, between the two measured around it.
  defp vel_at([{vel, level} | _], wanted) when wanted <= level, do: vel

  defp vel_at([{low, below}, {high, above} | rest], wanted) do
    if wanted <= above do
      low + (high - low) * (wanted - below) / max(above - below, 1.0e-9)
    else
      vel_at([{high, above} | rest], wanted)
    end
  end

  defp vel_at([{vel, _}], _), do: vel
end
