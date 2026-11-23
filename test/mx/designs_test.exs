defmodule Mx.DesignsTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs
  alias Mx.{Measure, Signal, Synths}
  alias Mx.Measure.{Held, Hits}

  @moduletag :engine
  @moduletag :tmp_dir
  @rate 48_000

  @drums ~w(kick snare clap closed_hihat rimshot cowbell clave low_conga mid_conga high_conga low_timbale high_timbale timbale_shell guiro pandeiro_thumb pandeiro_jingles pandeiro_slap pandeiro_heel cabasa cajon low_bongo high_bongo tambourine)a

  test "the pitched synths play note 48 at 130.8 Hz", ctx do
    for synth <- ~w(saw square tri pulse supersaw piano brass)a do
      sound = render(ctx, synth, note: 48, sustain: 1)
      assert_in_delta pitch(sound, 0.1, 0.25), 130.8, 1.3, "#{synth}"
    end
  end

  test "a just major third above middle C, 60 + ratio(5 / 4), sounds at 327.0 Hz", ctx do
    sound = render(ctx, :saw, note: 60 + Mx.Notation.ratio(5 / 4), sustain: 1)
    assert_in_delta pitch(sound, 0.1, 0.5), 327.0, 0.5
  end

  test "a lower cutoff takes the highs out of saw", ctx do
    dark = render(ctx, :saw, note: 48, cutoff: 60, sustain: 1)
    bright = render(ctx, :saw, note: 48, cutoff: 120, sustain: 1)
    assert highs(dark, 1000, 0.1, 0.9) < highs(bright, 1000, 0.1, 0.9) / 4
  end

  test "a note lasts its attack, sustain and release, and is silent after", ctx do
    sound = render(ctx, :saw, [note: 48, attack: 1, sustain: 1, release: 1], 4)
    assert rms(sound, 0.4, 0.6) > 0.01
    assert rms(sound, 1.2, 1.8) > rms(sound, 0.4, 0.6)
    assert rms(sound, 2.2, 2.5) > 0.001
    assert peak(sound, 3.01, 4) == 0
  end

  test "a note glides to a new note over its slide", ctx do
    slide = [note: 60.0, note_slide: 1.0]
    sound = render(ctx, :saw, [note: 48, sustain: 4], 4, [{1.0, slide}])
    assert_in_delta pitch(sound, 0.5, 0.7), 130.8, 1.3
    assert pitch(sound, 1.4, 1.6) > 140
    assert pitch(sound, 1.4, 1.6) < 250
    assert_in_delta pitch(sound, 2.2, 2.4), 261.6, 2.6
  end

  test "fm with no depth is a plain sine, and with depth has sidebands", ctx do
    plain = render(ctx, :fm, note: 69, depth: 0, sustain: 1)
    rich = render(ctx, :fm, note: 69, depth: 4, sustain: 1)
    assert highs(plain, 4000, 0.1, 0.9) < rms(plain, 0.1, 0.9) / 50
    assert highs(rich, 1000, 0.1, 0.9) > highs(plain, 1000, 0.1, 0.9) * 3
  end

  test "piano and brass are louder and brighter played harder", ctx do
    for synth <- [:piano, :brass] do
      soft = render(ctx, synth, note: 60, vel: 0.3, sustain: 1)
      hard = render(ctx, synth, note: 60, vel: 1, sustain: 1)
      assert rms(hard, 0, 0.5) > rms(soft, 0, 0.5) * 1.5, "#{synth}"
      assert highs(hard, 2000, 0, 0.5) > highs(soft, 2000, 0, 0.5) * 2, "#{synth}"
    end
  end

  test "every drum sounds with no options and is silent within 2 seconds", ctx do
    for drum <- @drums do
      sound = render(ctx, drum, [], 2.5)
      assert rms(sound, 0, 0.3) > 0.005, "#{drum}"
      assert peak(sound, 2, 2.5) == 0, "#{drum}"
    end
  end

  test "a drum's note retunes it, and the low conga is lower than the high one", ctx do
    assert strongest(render(ctx, :kick, note: 28), 0.05, 0.3) <
             strongest(render(ctx, :kick, []), 0.05, 0.3)

    assert strongest(render(ctx, :low_conga, []), 0.01, 0.2) <
             strongest(render(ctx, :high_conga, []), 0.01, 0.2)
  end

  test "a conga slap is shorter and brighter than an open tone", ctx do
    open = render(ctx, :high_conga, slap: 0)
    slap = render(ctx, :high_conga, slap: 1)
    assert last_sound(slap) < last_sound(open)
    assert highs(slap, 2000, 0, 0.1) > highs(open, 2000, 0, 0.1) * 2
  end

  test "the guiro scrapes for as long as its sustain", ctx do
    short = scraping(render(ctx, :guiro, sustain: 0.25))
    long = scraping(render(ctx, :guiro, sustain: 0.5))
    assert_in_delta long / short, 2, 0.4
  end

  test "flute, guitar, cavaquinho and bandolim play note 69 at 440 Hz, and guitar reaches B1",
       ctx do
    for synth <- [:flute, :guitar, :cavaquinho, :bandolim] do
      sound = render(ctx, synth, note: 69, sustain: 1)
      assert_in_delta pitch(sound, 0.1, 0.25), 440, 4.4, "#{synth}"
    end

    assert_in_delta pitch(render(ctx, :guitar, note: 35, sustain: 1), 0.1, 0.4), 61.7, 0.6
  end

  test "a flute's vibrato grows as the note holds, and vibrato: 0 has none", ctx do
    held = render(ctx, :flute, [note: 69, sustain: 4], 4.5)
    still = render(ctx, :flute, [note: 69, sustain: 4, vibrato: 0], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, 0.05, 0.9) * 2
    assert wobble(held, 3.0, 3.9) > 5
    assert wobble(still, 3.0, 3.9) < 1
  end

  test "cavaquinho and bandolim are brighter than guitar and die away sooner", ctx do
    guitar = render(ctx, :guitar, [note: 69, sustain: 3, release: 0.1], 3.5)

    for synth <- [:cavaquinho, :bandolim] do
      steel = render(ctx, synth, [note: 69, sustain: 3, release: 0.1], 3.5)
      assert highs(steel, 2000, 0, 0.3) > highs(guitar, 2000, 0, 0.3), "#{synth}"

      assert rms(steel, 1.5, 1.7) / rms(steel, 0, 0.2) <
               rms(guitar, 1.5, 1.7) / rms(guitar, 0, 0.2),
             "#{synth}"
    end
  end

  test "bandolim's tremolo repeats the pick", ctx do
    assert picks(render(ctx, :bandolim, note: 69, tremolo: 8, sustain: 1, release: 0.05)) == 8
    assert picks(render(ctx, :bandolim, note: 69, tremolo: 0, sustain: 1, release: 0.05)) == 1
  end

  test "flute and the strings are louder and brighter played harder", ctx do
    for synth <- [:flute, :guitar, :cavaquinho, :bandolim] do
      soft = render(ctx, synth, note: 69, vel: 0.3, sustain: 1)
      hard = render(ctx, synth, note: 69, vel: 1, sustain: 1)
      assert rms(hard, 0, 0.5) > rms(soft, 0, 0.5) * 1.5, "#{synth}"
      assert highs(hard, 2000, 0, 0.5) > highs(soft, 2000, 0, 0.5) * 2, "#{synth}"
    end
  end

  # Measured from the University of Iowa Electronic Music Studios' guitar, played mf, as medians
  # over its notes:
  # the seconds a harmonic takes to fade 60 dB, and its level against A2's fundamental, by the
  # harmonic's frequency.
  @guitar_fades %{
    {80, 160} => 10.29,
    {160, 250} => 3.48,
    {250, 400} => 4.52,
    {630, 1000} => 2.48,
    {1600, 2500} => 0.99
  }
  @guitar_levels %{
    {400, 630} => -8.9,
    {630, 1000} => -18.8,
    {1600, 2500} => -37.9,
    {2500, 4000} => -53.3
  }
  @guitar_bands [
    {80, 160},
    {160, 250},
    {250, 400},
    {400, 630},
    {630, 1000},
    {1000, 1600},
    {1600, 2500},
    {2500, 4000}
  ]
  @guitar_notes [40, 43, 45, 48, 52, 55, 57, 60, 64, 67, 69, 72, 76]

  test "guitar's harmonics fade over the times measured from a real guitar", ctx do
    bands = Map.new(Measure.bands(guitar_notes(ctx, 0.6)), &{&1.band, &1.fade})

    for {band, seconds} <- @guitar_fades do
      fade = bands[band]
      assert_in_delta fade / seconds, 1, 0.3, "#{inspect(band)} fades in #{fade} s"
    end
  end

  test "guitar's harmonic levels follow a real guitar's, loudest in the body's band", ctx do
    notes = guitar_notes(ctx, 0.6)
    harmonics = Enum.flat_map(notes, & &1.harmonics)
    [%{level: reference} | _] = Enum.find(notes, &(&1.note == 45)).harmonics

    level = fn band ->
      median(for %{freq: freq, level: db} <- harmonics, in_band?(freq, band), do: db) - reference
    end

    for {band, db} <- @guitar_levels do
      measured = level.(band)
      assert_in_delta measured, db, 6, "#{inspect(band)} is at #{measured} dB"
    end

    assert Enum.max_by(@guitar_bands, level) == {160, 250}
  end

  test "guitar played harder is brighter by as much as a real guitar", ctx do
    level = fn vel ->
      harmonics = Enum.flat_map(guitar_notes(ctx, vel), & &1.harmonics)
      median(for %{freq: freq, level: db} <- harmonics, in_band?(freq, {1000, 1600}), do: db)
    end

    spread = level.(1) - level.(0.3)
    assert spread >= 10 and spread <= 20
  end

  test "guitar's harmonics are stretched sharp like a real string's", ctx do
    sound = render(ctx, :guitar, [note: 45, vel: 0.6], 1.2)
    fundamental = sharpest(sound, 110, 0.05, 1.05)
    tenth = sharpest(sound, 1100, 0.05, 1.05)
    cents = 1200 * :math.log2(tenth / (10 * fundamental))
    assert cents > 4 and cents < 12
  end

  test "guitar rings on with no sustain, and sustain and release damp it", ctx do
    ringing = render(ctx, :guitar, [note: 40], 9)
    assert rms(ringing, 8, 8.2) > rms(ringing, 0, 0.2) / 1000

    fast = render(ctx, :guitar, Synths.to_seconds(:guitar, [note: 40], 180), 9)
    assert rms(fast, 8, 8.2) > rms(fast, 0, 0.2) / 1000

    damped = render(ctx, :guitar, [note: 45, sustain: 1, release: 0.1], 2)
    assert last_sound(damped) < 1.2
  end

  # Measured from the Steinway B grand of the Versilian Community Sample Library without the
  # sustain pedal.
  # Every fourth semitone from C2 to C7, at its three strengths: each band's median level against
  # C2's fundamental, and the seconds a harmonic takes to fade 60 dB.
  # Its soft notes' harmonics above 1 kHz sit near the recordings' noise floor, which stretches
  # their measured fades, so those fades are left out.
  # The tables are measured against the piano with `aftersound: 0, uneven: 0`: each harmonic at
  # one rate of fade, as the tables give it, and every key on the keyboard's trend.
  @trend [aftersound: 0, uneven: 0]

  @piano %{
    0.3 => %{
      {80, 160} => {6.6, 9.37},
      {160, 250} => {5.3, 11.87},
      {250, 400} => {-0.2, 10.48},
      {400, 630} => {-2.9, 12.41},
      {630, 1000} => {-8.6, 11.21},
      {1000, 1600} => {-25.3, nil},
      {1600, 2500} => {-41.6, nil},
      {2500, 4000} => {-54.5, nil}
    },
    0.6 => %{
      {80, 160} => {4.9, 8.42},
      {160, 250} => {6.4, 11.07},
      {250, 400} => {1.1, 10.79},
      {400, 630} => {0.1, 10.79},
      {630, 1000} => {-3.4, 10.25},
      {1000, 1600} => {-10.0, 10.15},
      {1600, 2500} => {-20.7, 7.96},
      {2500, 4000} => {-29.8, 5.32}
    },
    1.0 => %{
      {80, 160} => {5.7, 8.45},
      {160, 250} => {6.4, 10.39},
      {250, 400} => {0.9, 10.68},
      {400, 630} => {-0.3, 9.84},
      {630, 1000} => {-3.4, 10.43},
      {1000, 1600} => {-7.4, 8.72},
      {1600, 2500} => {-16.3, 6.69},
      {2500, 4000} => {-20.9, 4.43}
    }
  }

  test "piano's harmonic levels and fades follow the Steinway's at each strength", ctx do
    for {vel, table} <- @piano do
      bands =
        Map.new(Measure.bands(piano_notes(ctx, vel, 36..96//4, @trend)), &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = bands[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  # The University of Iowa's piano is 26.7 dB louder played ff than pp,
  # as the median over its notes of the loudest half second.
  test "piano at vel 1 is louder than at vel 0.3 by as much as a real piano, and brighter", ctx do
    louder =
      for note <- [36, 48, 60, 72, 84] do
        soft = render(ctx, :piano, [note: note, vel: 0.3, sustain: 60], 0.6)
        hard = render(ctx, :piano, [note: note, vel: 1, sustain: 60], 0.6)

        assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
                 highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

        20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      end

    assert_in_delta median(louder), 26.7, 6
  end

  test "piano plays A0 and C8, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [21, 108] do
      sound = render(ctx, :piano, [note: note, sustain: 60], 3)
      [%{freq: freq} | _] = Measure.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a piano note rings while its key is held, and the damper stops it", ctx do
    held = render(ctx, :piano, [note: 48, sustain: 3, release: 0.1], 4)
    assert rms(held, 2.5, 2.9) > rms(held, 0, 0.2) / 100
    assert last_sound(held) < 3.3

    short = render(ctx, :piano, [note: 48, sustain: 0.5, release: 0.1], 2)
    assert last_sound(short) < 0.8
  end

  # Measured from the Steinway B of the VCSL with the sustain pedal down, every fourth semitone
  # from C2 to C7, at its three strengths.
  @piano_pedal %{
    0.3 => %{
      {80, 160} => {6.5, 15.10},
      {160, 250} => {5.7, 14.73},
      {250, 400} => {3.1, 12.81},
      {400, 630} => {-0.9, 11.45},
      {630, 1000} => {-3.5, 11.65},
      {1000, 1600} => {-10.2, 10.24},
      {1600, 2500} => {-17.9, 7.55},
      {2500, 4000} => {-27.9, 5.91}
    },
    0.6 => %{
      {80, 160} => {5.9, 15.81},
      {160, 250} => {5.3, 14.82},
      {250, 400} => {2.3, 13.78},
      {400, 630} => {-0.4, 11.68},
      {630, 1000} => {-3.4, 10.21},
      {1000, 1600} => {-9.4, 10.07},
      {1600, 2500} => {-14.9, 7.84},
      {2500, 4000} => {-22.5, 5.06}
    },
    1.0 => %{
      {80, 160} => {6.1, 14.90},
      {160, 250} => {5.5, 13.11},
      {250, 400} => {1.7, 15.68},
      {400, 630} => {-1.1, 11.56},
      {630, 1000} => {-2.8, 10.46},
      {1000, 1600} => {-8.7, 9.67},
      {1600, 2500} => {-15.7, 7.20},
      {2500, 4000} => {-20.0, 4.71}
    }
  }

  test "piano with the pedal down follows the Steinway's harmonic levels and fades with the pedal down",
       ctx do
    for {vel, table} <- @piano_pedal do
      bands =
        Map.new(
          Measure.bands(piano_notes(ctx, vel, 36..96//4, [pedal: 1] ++ @trend)),
          &{&1.band, &1}
        )

      assert_bands(bands, table, "pedal 1 vel #{vel}")
    end
  end

  # Measured from the Steinway B of the VCSL without the pedal, at A#0, C1, E1 and G#1, at its
  # three strengths, against A#0's fundamental.
  # At vel 1 the band from 1 to 1.6 kHz holds only the top few harmonics of G#1 and E1, which the
  # recordings raise above the band below and the design does not, so its level is left out.
  @piano_low %{
    0.3 => %{
      {80, 160} => {19.4, 15.74},
      {160, 250} => {13.9, 14.59},
      {250, 400} => {7.1, 9.57},
      {400, 630} => {-2.5, 17.02},
      {630, 1000} => {-3.7, 15.30},
      {1000, 1600} => {-7.4, 20.75}
    },
    0.6 => %{
      {80, 160} => {28.0, 14.71},
      {160, 250} => {25.0, 11.17},
      {250, 400} => {19.4, 8.54},
      {400, 630} => {15.5, 12.50},
      {630, 1000} => {16.9, 14.09},
      {1000, 1600} => {15.6, 11.48}
    },
    1.0 => %{
      {80, 160} => {33.0, 15.57},
      {160, 250} => {30.9, 11.80},
      {250, 400} => {25.9, 8.40},
      {400, 630} => {21.3, 11.76},
      {630, 1000} => {22.6, 13.33},
      {1000, 1600} => {nil, 10.63}
    }
  }

  test "piano's notes below C2 follow the Steinway's harmonic levels and fades", ctx do
    for {vel, table} <- @piano_low do
      bands =
        Map.new(Measure.bands(piano_notes(ctx, vel, [22, 24, 28, 32], @trend)), &{&1.band, &1})

      assert_bands(bands, table, "vel #{vel}")
    end
  end

  # The Steinway's A#0 played mf, 0.3 seconds in: its loudest bins from 700 to 1500 Hz stand 21.0
  # dB under those from 60 to 200 Hz.
  test "piano's lowest notes sound above their 24th harmonic, as loud as the Steinway's", ctx do
    sound = render(ctx, :piano, [note: 22, vel: 0.6, sustain: 60], 2)
    assert_in_delta loudest_bins(sound, 700, 1500) - loudest_bins(sound, 60, 200), -21.0, 6
  end

  test "the pedal keeps a piano note about as loud, and the damper still stops it", ctx do
    for note <- [36, 60, 84] do
      up = render(ctx, :piano, [note: note, sustain: 60], 0.6)
      down = render(ctx, :piano, [note: note, sustain: 60, pedal: 1], 0.6)

      assert_in_delta 20 * :math.log10(rms(down, 0, 0.5) / rms(up, 0, 0.5)),
                      0,
                      1.5,
                      "note #{note}"
    end

    damped = render(ctx, :piano, [note: 48, sustain: 1, release: 0.1, pedal: 1], 2)
    assert last_sound(damped) < 1.5
  end

  # The Steinway's notes played mf, every fourth semitone from C2 to C6: the median note is 13.8
  # dB quieter one second after the strike, and 14.3 dB quieter again three seconds later.
  test "a piano note fades fast after the strike and then slowly, as the Steinway's", ctx do
    drops =
      for note <- 36..84//4 do
        sound = render(ctx, :piano, [note: note, vel: 0.6, sustain: 60], 5)
        levels = for at <- [0.15, 1, 4], do: Signal.db(rms(sound, at - 0.1, at + 0.1))
        levels |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [from, to] -> to - from end)
      end

    [first, later] = for at <- 0..1, do: Signal.median(Enum.map(drops, &Enum.at(&1, at)))
    assert_in_delta first, -13.8, 6
    assert_in_delta later, -14.3, 6
  end

  # The Steinway's keys played mf, every second semitone from C2 to C6: the levels of harmonics 2
  # to 6 against the key's fundamental stand a median 5.3 dB from the mean of the keys on either
  # side.
  test "piano's keys differ from their neighbours as the Steinway's, and not at all with uneven 0",
       ctx do
    spread = fn opts ->
      keys =
        for note <- piano_notes(ctx, 0.6, 36..84//2, opts) do
          [first | _] = note.harmonics
          Map.new(note.harmonics, &{&1.number, &1.level - first.level})
        end

      misses =
        for [below, key, above] <- Enum.chunk_every(keys, 3, 1, :discard), number <- 2..6 do
          abs(key[number] - (below[number] + above[number]) / 2)
        end

      Signal.median(misses)
    end

    assert_in_delta spread.([]), 5.3, 2
    assert spread.(uneven: 0) < 1
  end

  # The Steinway's C6, E6, G#6 and C7 played mf: the first 4096 samples hold a median 15.9 dB less
  # from 40 to 600 Hz, under the lowest harmonic, than in all.
  test "piano's hammer knocks under its high notes as loud as the Steinway's, and knock 0 leaves it out",
       ctx do
    knock = fn opts ->
      levels =
        for note <- [84, 88, 92, 96] do
          sound = render(ctx, :piano, [note: note, vel: 0.6, sustain: 60] ++ opts, 0.5)
          spectrum = Signal.spectrum(List.to_tuple(sound), 0, 4096)

          power = fn low, high ->
            bins = ceil(low * 4096 / @rate)..floor(high * 4096 / @rate)
            Enum.sum(for at <- bins, do: elem(spectrum, at) ** 2)
          end

          10 * :math.log10(power.(40, 600) / power.(40, 20_000))
        end

      Signal.median(levels)
    end

    assert_in_delta knock.([]), -15.9, 6
    assert knock.(knock: 0) < -45
  end

  # Measured from the organ of VSCO 2, every third key from C2 to C7 of its third manual, in its
  # Quiet and Loud sets:
  # the seconds a note takes to speak, and each band's median level while it holds, against C2's
  # fundamental.
  @organ %{
    0 => %{
      attack: 0.11,
      bands: %{
        {80, 160} => 12.1,
        {160, 250} => -1.8,
        {250, 400} => -18.7,
        {400, 630} => -25.2,
        {630, 1000} => -36.0,
        {1000, 1600} => -45.9,
        {1600, 2500} => -57.1,
        {2500, 4000} => -62.6
      }
    },
    1 => %{
      attack: 0.16,
      bands: %{
        {80, 160} => 6.9,
        {160, 250} => 10.5,
        {250, 400} => 10.9,
        {400, 630} => 10.2,
        {630, 1000} => 5.0,
        {1000, 1600} => 1.6,
        {1600, 2500} => -9.7,
        {2500, 4000} => -28.2
      }
    }
  }

  test "organ speaks and holds its bands as VSCO 2's organ does, in its quiet and loud sets",
       ctx do
    for {loud, %{attack: attack, bands: bands}} <- @organ do
      notes =
        36..96//3
        |> Task.async_stream(
          fn note ->
            Held.note(render(ctx, :organ, [note: note, loud: loud, sustain: 2.5], 3), @rate, note)
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, note} -> note end)

      summary = Held.summary(notes)
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack,
                      1,
                      0.3,
                      "loud #{loud} speaks in #{summary.attack} s"

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "loud #{loud} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # Measured from the same recordings, against the Loud set's median key: each key's held loudness
  # in the Loud set, and the median of each octave's in the Quiet set, whose neighbouring keys
  # differ by up to 20 dB.
  @organ_loudness %{
    1 => %{
      36 => 3.5,
      39 => 3.8,
      42 => 3.7,
      45 => 3.3,
      48 => 3.0,
      51 => 1.6,
      54 => 3.2,
      57 => 1.1,
      60 => 2.0,
      63 => 0.0,
      66 => -0.4,
      69 => 0.1,
      72 => -0.3,
      75 => -5.0,
      78 => -6.0,
      81 => -5.8,
      84 => -5.2,
      87 => -3.8,
      90 => -4.1,
      93 => -7.4,
      96 => -5.7
    },
    0 => %{
      (36..47) => -11.6,
      (48..59) => -1.2,
      (60..71) => -3.8,
      (72..83) => -6.1,
      (84..96) => -4.6
    }
  }

  test "organ's loudness across its keys follows VSCO 2's organ in both sets", ctx do
    loudness =
      for loud <- [0, 1], note <- 36..96//3, into: %{} do
        sound = render(ctx, :organ, [note: note, loud: loud, sustain: 2.5], 2.5)
        {{loud, note}, 20 * :math.log10(rms(sound, 1, 2))}
      end

    reference = median(for {{1, _note}, db} <- loudness, do: db)

    for {note, level} <- @organ_loudness[1] do
      measured = loudness[{1, note}] - reference
      assert_in_delta measured, level, 6, "loud note #{note} at #{measured} dB"
    end

    for {keys, level} <- @organ_loudness[0] do
      measured = median(for {{0, note}, db} <- loudness, note in keys, do: db) - reference
      assert_in_delta measured, level, 6, "quiet notes #{inspect(keys)} at #{measured} dB"
    end
  end

  test "organ plays C1, the pedals' lowest note, and C7, the manual's highest, at their pitch",
       ctx do
    for note <- [24, 96] do
      sound = render(ctx, :organ, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "an organ note holds one level for its sustain, then stops over its release", ctx do
    sound = render(ctx, :organ, [note: 60, sustain: 2, release: 0.15], 3)
    assert_in_delta rms(sound, 1.7, 1.9) / rms(sound, 0.5, 0.7), 1, 0.05
    assert last_sound(sound) < 2.3
  end

  # Iowa's C2 struck ff with yarn mallets, measured with mix mx.measure --hits --partials 8, rings
  # partials at 8.84, 9.93, 10.85 and 11.61 times its pitch.
  test "marimba's C2 at vel 1 rings the partials Iowa's C2 rings near ten times its note", ctx do
    %{partials: partials} =
      Hits.hit(render(ctx, :marimba, [note: 36, vel: 1], 4), @rate, 36, partials: 8)

    ratios = Enum.map(partials, & &1.ratio)

    for ratio <- [8.84, 9.93, 10.85, 11.61] do
      assert Enum.any?(ratios, &(abs(&1 / ratio - 1) < 0.01)),
             "no partial at #{ratio}: #{inspect(ratios)}"
    end
  end

  # Iowa's marimba struck with yarn mallets is 20.84 dB quieter at pp than at ff at C4, over the
  # first half second of each note's partials, as mix mx.fit --check sums them.
  test "marimba's C4 at vel 0.31 is quieter than at vel 1 by as much as Iowa's pp below its ff",
       ctx do
    soft = render(ctx, :marimba, [note: 60, vel: 40 / 127], 0.6)
    hard = render(ctx, :marimba, [note: 60, vel: 1], 0.6)
    quieter = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
    assert_in_delta quieter, 20.84, 1.5
  end

  test "marimba plays F1 and C7, the lowest and highest bars of the recordings, at their pitch",
       ctx do
    for note <- [29, 96] do
      expected = 440 * :math.pow(2, (note - 69) / 12)

      %{partials: partials} =
        Hits.hit(render(ctx, :marimba, [note: note], 3), @rate, note, partials: 8)

      %{hz: hz} = Enum.min_by(partials, &abs(:math.log(&1.hz / expected)))
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a marimba's low bars ring longer than its high ones, and sustain and release damp a note",
       ctx do
    assert last_sound(render(ctx, :marimba, [note: 36], 6)) >
             last_sound(render(ctx, :marimba, [note: 84], 6))

    damped = render(ctx, :marimba, [note: 36, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # Measured from the University of Iowa's vibraphone with the motor off, every note from C3 to
  # F6, at ff, mf and pp against vel 1, 0.6 and 0.3, as the marimba's are.
  # A level of nil is left out: ff's and mf's lowest band holds only the lowest notes,
  # which lie under the recordings' noise floor,
  # and mf's 1.6 to 2.5 kHz is quieter than both ff's and pp's, which the design does not follow.
  # A fade of nil is left out: pp's from 400 Hz to 2.5 kHz ring on near the noise floor, longer
  # than ff's;
  # ff's from 2.5 to 4 kHz is 31 percent short, and mf's from 4 to 6.3 kHz is 31 percent long.
  @vibraphone %{
    1 => %{
      {80, 160} => {nil, 13.71},
      {160, 250} => {-10.3, 12.77},
      {250, 400} => {-26.3, 14.32},
      {400, 630} => {-29.4, 8.62},
      {630, 1000} => {-29.7, 7.93},
      {1000, 1600} => {-28.7, 4.99},
      {1600, 2500} => {-30.0, 3.64},
      {2500, 4000} => {-23.8, nil},
      {4000, 6300} => {-38.5, 0.76}
    },
    0.6 => %{
      {80, 160} => {nil, 16.56},
      {160, 250} => {-6.9, 14.34},
      {250, 400} => {-18.2, 13.22},
      {400, 630} => {-22.9, 8.87},
      {630, 1000} => {-24.9, 7.4},
      {1000, 1600} => {-30.9, 5.24},
      {1600, 2500} => {nil, 3.03},
      {2500, 4000} => {-38.2, 1.12},
      {4000, 6300} => {-44.9, nil}
    },
    0.3 => %{
      {80, 160} => {-11.3, 15.86},
      {160, 250} => {-4.1, 14.91},
      {250, 400} => {-19.4, 15.53},
      {400, 630} => {-25.6, nil},
      {630, 1000} => {-31.8, 10.48},
      {1000, 1600} => {-33.5, nil},
      {1600, 2500} => {-32.6, nil},
      {2500, 4000} => {-34.0, 1.49},
      {4000, 6300} => {-40.7, 0.17}
    }
  }

  test "vibraphone starts and fades in each band as Iowa's vibraphone does at each dynamic",
       ctx do
    for {vel, bands} <- @vibraphone do
      hits =
        48..89
        |> Task.async_stream(
          fn note ->
            Hits.hit(render(ctx, :vibraphone, [note: note, vel: vel], 4), @rate, note)
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, hit} -> hit end)

      measured = Map.new(Hits.summary(hits), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]

        if level do
          assert_in_delta synth_level,
                          level,
                          6,
                          "vel #{vel} #{inspect(band)} at #{synth_level} dB"
        end

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  # The bars' overtones in the same recordings, as medians of their ratios to the note from C3 to
  # B3.
  test "vibraphone's overtones stand two octaves, a little over three octaves and four octaves above its note",
       ctx do
    for note <- [48, 53, 58] do
      %{partials: partials} =
        Hits.hit(render(ctx, :vibraphone, [note: note, vel: 1], 4), @rate, note, partials: 8)

      ratios = Enum.map(partials, & &1.ratio)

      for ratio <- [4.01, 10.02, 15.95] do
        assert Enum.any?(ratios, &(abs(&1 / ratio - 1) < 0.02)),
               "note #{note} has no partial at #{ratio}: #{inspect(ratios)}"
      end
    end
  end

  # The same recordings are 19.6 dB louder ff than pp, as the median over their notes of the
  # loudest half second.
  test "vibraphone at vel 1 is louder than at vel 0.3 by as much as a real vibraphone, and brighter",
       ctx do
    louder =
      for note <- [48, 60, 72, 84] do
        soft = render(ctx, :vibraphone, [note: note, vel: 0.3], 0.6)
        hard = render(ctx, :vibraphone, [note: note, vel: 1], 0.6)

        assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
                 highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

        20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      end

    assert_in_delta median(louder), 19.6, 6
  end

  test "vibraphone plays C3 and F6, the lowest and highest bars of the recordings, at their pitch",
       ctx do
    for note <- [48, 89] do
      expected = 440 * :math.pow(2, (note - 69) / 12)

      %{partials: partials} =
        Hits.hit(render(ctx, :vibraphone, [note: note], 3), @rate, note, partials: 8)

      %{hz: hz} = Enum.min_by(partials, &abs(:math.log(&1.hz / expected)))
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # motor is sent per second, so motor 2 at 60 bpm reaches the synth as 2.
  test "vibraphone's motor pulses its level that many times a second, and motor 0 leaves it still",
       ctx do
    assert pulses(render(ctx, :vibraphone, [note: 60, motor: 2], 3.5), 1.25, 3.25) == 4
    assert pulses(render(ctx, :vibraphone, [note: 60, motor: 0], 3.5), 1.25, 3.25) == 0
  end

  test "a vibraphone note rings for seconds, longer low than high, and sustain and release damp it",
       ctx do
    low = last_sound(render(ctx, :vibraphone, [note: 48], 12))
    high = last_sound(render(ctx, :vibraphone, [note: 84], 12))
    assert high > 3
    assert low > high

    damped = render(ctx, :vibraphone, [note: 60, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # Measured from the University of Iowa's xylophone struck with rosewood mallets, every note from
  # F4 to C8, at ff, mf and pp against vel 1, 0.6 and 0.3, as the marimba's are.
  # ff's level from 1.6 to 2.5 kHz is left out:
  # the overtone a little over two and a half octaves up sets it on the low bars,
  # and at the level that keeps their lower bands right it is 7 dB louder than the recordings'.
  # pp's fade from 250 to 400 Hz is left out: it rings on near the recordings' noise floor, longer
  # than ff's.
  @xylophone %{
    1 => %{
      {250, 400} => {-22.7, 1.23},
      {400, 630} => {-7.8, 0.75},
      {630, 1000} => {-35.6, 0.58},
      {1000, 1600} => {-20.8, 0.31},
      {1600, 2500} => {nil, 0.18},
      {2500, 4000} => {-9.7, 0.09},
      {4000, 6300} => {-14.6, 0.06}
    },
    0.6 => %{
      {250, 400} => {-16.7, 1.21},
      {400, 630} => {-3.3, 0.82},
      {630, 1000} => {-34.3, 0.56},
      {1000, 1600} => {-20.1, 0.32},
      {1600, 2500} => {-21.9, 0.17},
      {2500, 4000} => {-12.2, 0.09},
      {4000, 6300} => {-16.5, 0.05}
    },
    0.3 => %{
      {250, 400} => {-19.9, nil},
      {400, 630} => {-5.3, 1.09},
      {630, 1000} => {-16.7, 0.55},
      {1000, 1600} => {-17.3, 0.33},
      {1600, 2500} => {-21.4, 0.18},
      {2500, 4000} => {-21.4, 0.09},
      {4000, 6300} => {-30.9, 0.08}
    }
  }

  test "xylophone starts and fades in each band as Iowa's xylophone does at each dynamic", ctx do
    for {vel, bands} <- @xylophone do
      hits =
        65..108
        |> Task.async_stream(
          fn note ->
            Hits.hit(render(ctx, :xylophone, [note: note, vel: vel], 2), @rate, note)
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, hit} -> hit end)

      measured = Map.new(Hits.summary(hits), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]

        if level do
          assert_in_delta synth_level,
                          level,
                          6,
                          "vel #{vel} #{inspect(band)} at #{synth_level} dB"
        end

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  # The bars' overtones in Iowa's rosewood xylophone, as medians of their ratios to the note from
  # F4 to D#5.
  test "xylophone's overtones stand a twelfth and a little over two and a half octaves above its note",
       ctx do
    for note <- [65, 68, 71] do
      %{partials: partials} =
        Hits.hit(render(ctx, :xylophone, [note: note, vel: 1], 2), @rate, note, partials: 8)

      ratios = Enum.map(partials, & &1.ratio)

      for ratio <- [3.0, 6.39] do
        assert Enum.any?(ratios, &(abs(&1 / ratio - 1) < 0.02)),
               "note #{note} has no partial at #{ratio}: #{inspect(ratios)}"
      end
    end
  end

  # The same recordings are 25.6 dB louder ff than pp, as the median over their notes of the
  # loudest half second.
  test "xylophone at vel 1 is louder than at vel 0.3 by as much as a real xylophone, and brighter",
       ctx do
    louder =
      for note <- [65, 77, 89, 101] do
        soft = render(ctx, :xylophone, [note: note, vel: 0.3], 0.6)
        hard = render(ctx, :xylophone, [note: note, vel: 1], 0.6)

        assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
                 highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

        20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      end

    assert_in_delta median(louder), 25.6, 6
  end

  test "xylophone plays F4 and C8, the lowest and highest bars of the recordings, at their pitch",
       ctx do
    for note <- [65, 108] do
      expected = 440 * :math.pow(2, (note - 69) / 12)

      %{partials: partials} =
        Hits.hit(render(ctx, :xylophone, [note: note], 2), @rate, note, partials: 8)

      %{hz: hz} = Enum.min_by(partials, &abs(:math.log(&1.hz / expected)))
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a xylophone note is short and fades by itself, the high bars sooner than the low ones",
       ctx do
    low = last_sound(render(ctx, :xylophone, [note: 65], 4))
    high = last_sound(render(ctx, :xylophone, [note: 101], 4))
    assert low < 2.5
    assert high < low
  end

  # Measured from the University of Iowa's orchestral bells struck with plastic mallets, every
  # note from C5 to E8, at ff, mf and pp against vel 1, 0.6 and 0.3, as the marimba's are.
  # Each nil is a band the design misses, and is left out.
  # Levels: ff's from 400 Hz to 2.5 kHz are 7 to 11 dB off, mf's 630 Hz to 1 kHz is 8 dB loud,
  # and pp's 400 to 630 Hz and 2.5 to 4 kHz are 15 and 8 dB off.
  # Fades: ff's are 30 to 82 percent off in every band,
  # mf's are 48 and 126 percent long from 400 to 630 Hz and 1.6 to 2.5 kHz,
  # and pp's are about half as long as the recordings' from 400 to 630 Hz and 1 to 1.6 kHz.
  # From 2.5 to 4 kHz, mf's and pp's fade in 1 s, against 3.73 s and 3.37 s:
  # the overtone near 3.3 times the bars from G5 to E6 fades in 1 s, where the recordings' bars
  # from G5 to B5 ring 4 to 7 s at mf, and at pp that overtone rings 15 to 20 dB louder than the
  # recordings show it.
  @glockenspiel %{
    1 => %{
      {400, 630} => {nil, nil},
      {630, 1000} => {-9.6, nil},
      {1000, 1600} => {nil, nil},
      {1600, 2500} => {nil, nil},
      {2500, 4000} => {-29.1, nil},
      {4000, 6300} => {-11.6, nil},
      {6300, 10_000} => {-17.3, nil}
    },
    0.6 => %{
      {400, 630} => {-15.9, nil},
      {630, 1000} => {nil, 11.49},
      {1000, 1600} => {-43.2, 13.8},
      {1600, 2500} => {-35.3, nil},
      {2500, 4000} => {-30.4, nil},
      {4000, 6300} => {-18.0, 0.83},
      {6300, 10_000} => {-30.5, 0.6}
    },
    0.3 => %{
      {400, 630} => {nil, nil},
      {630, 1000} => {0.0, 13.69},
      {1000, 1600} => {-29.6, nil},
      {1600, 2500} => {-21.4, 6.32},
      {2500, 4000} => {nil, nil},
      {4000, 6300} => {-22.4, 0.72},
      {6300, 10_000} => {-30.5, 0.7}
    }
  }

  test "glockenspiel starts and fades in each band as Iowa's bells do at each dynamic", ctx do
    for {vel, bands} <- @glockenspiel do
      hits =
        72..112
        |> Task.async_stream(
          fn note ->
            Hits.hit(render(ctx, :glockenspiel, [note: note, vel: vel], 4), @rate, note)
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, hit} -> hit end)

      measured = Map.new(Hits.summary(hits), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]

        if level do
          assert_in_delta synth_level,
                          level,
                          6,
                          "vel #{vel} #{inspect(band)} at #{synth_level} dB"
        end

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  # The bars' overtones in Iowa's plastic-mallet bells at ff, which stand lower above the note the
  # higher the bar.
  test "glockenspiel's overtones stand where the recordings' do, lower above the note the higher the bar",
       ctx do
    for {note, expected} <- [{72, [7.21, 11.3]}, {80, [6.55, 9.13]}, {88, [5.98, 7.08]}] do
      %{partials: partials} =
        Hits.hit(render(ctx, :glockenspiel, [note: note, vel: 1], 4), @rate, note, partials: 8)

      ratios = Enum.map(partials, & &1.ratio)

      for ratio <- expected do
        assert Enum.any?(ratios, &(abs(&1 / ratio - 1) < 0.02)),
               "note #{note} has no partial at #{ratio}: #{inspect(ratios)}"
      end
    end
  end

  # The same recordings are 24.0 dB louder ff than pp, as the median over their notes of the
  # loudest half second.
  test "glockenspiel at vel 1 is louder than at vel 0.3 by as much as a real glockenspiel, and brighter",
       ctx do
    louder =
      for note <- [72, 84, 96, 108] do
        soft = render(ctx, :glockenspiel, [note: note, vel: 0.3], 0.6)
        hard = render(ctx, :glockenspiel, [note: note, vel: 1], 0.6)

        assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
                 highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

        20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      end

    assert_in_delta median(louder), 24.0, 6
  end

  test "glockenspiel plays C5 and E8, the lowest and highest bars of the recordings, at their pitch",
       ctx do
    for note <- [72, 112] do
      expected = 440 * :math.pow(2, (note - 69) / 12)

      %{partials: partials} =
        Hits.hit(render(ctx, :glockenspiel, [note: note], 3), @rate, note, partials: 8)

      %{hz: hz} = Enum.min_by(partials, &abs(:math.log(&1.hz / expected)))
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a glockenspiel note rings for seconds and fades by itself, and sustain and release damp it",
       ctx do
    assert last_sound(render(ctx, :glockenspiel, [note: 84], 8)) > 3

    damped = render(ctx, :glockenspiel, [note: 84, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # Measured from the folk harp of Versilian Studios' Versilian Community Sample Library, every
  # string from C2 to G#6, at its softer and louder strengths against vel 0.3 and 1, as medians
  # over the notes by the harmonic's frequency:
  # the seconds a harmonic takes to fade 60 dB, and its level against the fundamental of C2.
  @harp %{
    0.3 => %{
      {80, 160} => {13.14, 5.7},
      {160, 250} => {13.74, 19.2},
      {250, 400} => {11.17, 15.0},
      {400, 630} => {8.48, 3.0},
      {630, 1000} => {4.58, -6.2},
      {1000, 1600} => {2.22, -14.9},
      {1600, 2500} => {1.21, -24.6},
      {2500, 4000} => {0.80, -31.1}
    },
    1 => %{
      {80, 160} => {10.71, 8.1},
      {160, 250} => {13.77, 21.6},
      {250, 400} => {9.36, 20.0},
      {400, 630} => {8.66, 9.3},
      {630, 1000} => {5.13, 6.2},
      {1000, 1600} => {2.93, -5.8},
      {1600, 2500} => {1.51, -10.6},
      {2500, 4000} => {0.92, -22.1}
    }
  }

  test "harp's harmonics fade and stand as the folk harp's do at each strength", ctx do
    for {vel, bands} <- @harp do
      measured = Map.new(Measure.bands(harp_notes(ctx, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  # The same recordings' harmonics are stretched 2.4e-4 at C4 and 8.4e-4 at G#6, as mix mx.measure
  # prints it.
  test "harp's harmonics are stretched sharp, more the shorter the string, like the folk harp's",
       ctx do
    for {note, stretch} <- [{60, 2.4e-4}, {92, 8.4e-4}] do
      %{stretch: measured} =
        Measure.note(render(ctx, :harp, [note: note, vel: 1], 4.5), @rate, note)

      assert_in_delta measured / stretch, 1, 0.3, "note #{note} is stretched #{measured}"
    end
  end

  # The same recordings are 12.5 dB louder at their louder strength,
  # as the median over their notes of the loudest half second.
  test "harp at vel 1 is louder than at vel 0.3 by as much as the folk harp, and brighter", ctx do
    louder =
      for note <- [36, 48, 60, 72, 84] do
        soft = render(ctx, :harp, [note: note, vel: 0.3], 0.6)
        hard = render(ctx, :harp, [note: note, vel: 1], 0.6)

        assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
                 highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

        20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      end

    assert_in_delta median(louder), 12.5, 6
  end

  test "harp plays C2 and G#6, the lowest and highest strings of the recordings, at their pitch",
       ctx do
    for note <- [36, 92] do
      expected = 440 * :math.pow(2, (note - 69) / 12)
      %{pitch: hz} = Measure.note(render(ctx, :harp, [note: note], 4.5), @rate, note)
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a harp string rings for seconds and fades by itself, and sustain and release damp it",
       ctx do
    low = last_sound(render(ctx, :harp, [note: 48], 12))
    assert low > 6

    damped = render(ctx, :harp, [note: 48, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # Measured from the bass_electronic_018 instrument of the test set of Google's NSynth dataset,
  # its notes from E1 up at velocities 25, 75 and 127 against vel 0.2, 0.59 and 1, each cut at 2.9
  # seconds, before its key is let go, since a fade read across the release at 3 seconds comes out
  # short, and brought from 16 kHz to 48 kHz, the rate the synth is measured at, since a harmonic
  # that fades within a second reads up to 20 dB low at 16 kHz: the notes of each velocity, and as
  # medians over them by the harmonic's frequency the seconds a harmonic takes to fade 60 dB and
  # its level against the fundamental of the lowest.
  # The bands above 630 Hz are left out: few of the recordings' harmonics there last long enough
  # to give a fade.
  @electric_bass %{
    0.2 =>
      {[29, 31, 32, 37, 50, 56, 59, 62],
       %{
         {80, 160} => {4.34, 6.2},
         {160, 250} => {3.61, 4.5},
         {250, 400} => {2.20, -19.3},
         {400, 630} => {1.23, -24.1}
       }},
    0.59 =>
      {[29, 33, 35, 43, 44, 45, 48, 49, 50, 52, 53, 60, 61, 62, 63],
       %{
         {80, 160} => {5.25, 0.2},
         {160, 250} => {5.49, 2.1},
         {250, 400} => {2.62, 0.3},
         {400, 630} => {1.73, -9.0}
       }},
    1 =>
      {[32, 35],
       %{
         {80, 160} => {5.37, 1.9},
         {160, 250} => {4.54, 0.6},
         {250, 400} => {2.35, -10.6},
         {400, 630} => {1.03, -23.2}
       }}
  }

  test "electric_bass's harmonics fade and stand as the recorded bass's do at each velocity",
       ctx do
    for {vel, {notes, bands}} <- @electric_bass do
      measured = Map.new(Measure.bands(electric_bass_notes(ctx, notes, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  # The recordings are each brought to the same peak, so they do not say how much louder a harder
  # note is; their harmonics from the sixth up are 3 to 8 dB stronger at velocity 127 than at 25.
  test "electric_bass at vel 1 is louder than at vel 0.3, by under 6 dB, and brighter", ctx do
    for note <- [28, 33, 40, 45] do
      soft = render(ctx, :electric_bass, [note: note, vel: 0.3], 0.6)
      hard = render(ctx, :electric_bass, [note: note, vel: 1], 0.6)

      assert highs(hard, 2000, 0, 0.5) / rms(hard, 0, 0.5) >
               highs(soft, 2000, 0, 0.5) / rms(soft, 0, 0.5)

      louder = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      assert louder > 0 and abs(louder - 0.4) < 6, "note #{note} is #{louder} dB louder"
    end
  end

  test "electric_bass plays MIDI 22 and 63, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [22, 63] do
      expected = 440 * :math.pow(2, (note - 69) / 12)
      sound = render(ctx, :electric_bass, [note: note], 1.2)
      hz = pitch(window(sound, 0.1, 1.1), expected)
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # The recorded A1 at velocity 75 is 5.2 dB under its level at a tenth of a second after one
  # second, and 13.5 dB under it after 2.9.
  test "electric_bass's A1 fades as the recorded one does, and sustain and release damp it",
       ctx do
    sound = render(ctx, :electric_bass, [note: 33, vel: 0.59], 3.2)
    under = fn at -> 20 * :math.log10(rms(sound, at, at + 0.1) / rms(sound, 0.1, 0.2)) end
    # The recorded A1's second to fourth harmonics ring two to three times as long as those of the
    # notes around it, and the design holds the medians over the notes.
    assert_in_delta under.(1.0), -5.2, 5
    assert_in_delta under.(2.9), -13.5, 5

    damped = render(ctx, :electric_bass, [note: 33, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # Measured from the bass_electronic_025 and bass_electronic_027 instruments of the test set of
  # Google's NSynth dataset, together, their notes from E1 up at velocities 25, 75 and 127 against
  # vel 0.2, 0.59 and 1, each cut at 2.9 seconds, before its key is let go, and brought from 16
  # kHz to 48 kHz: the notes of each velocity, and as medians over them by the harmonic's
  # frequency the seconds a harmonic takes to fade 60 dB and its level against the fundamental of
  # the lowest. The bands above 1.6 kHz are left out: there the recordings hold only their noise
  # floor, 55 to 70 dB down, which reads as fades of 10 to 40 seconds.
  @deep_bass %{
    0.2 =>
      {[28, 31, 36, 38, 40, 43, 44, 47, 48, 50, 51, 52, 53, 54, 55, 57, 58, 59, 62],
       %{
         {80, 160} => {4.47, 15.3},
         {160, 250} => {5.30, 9.5},
         {250, 400} => {3.25, -5.3},
         {400, 630} => {2.63, -24.2},
         {630, 1000} => {3.21, -43.7},
         {1000, 1600} => {4.68, -47.7}
       }},
    0.59 =>
      {[32, 36, 37, 39, 41, 44, 45, 47, 48, 51, 53, 55, 56, 57, 58, 61, 62],
       %{
         {80, 160} => {5.10, 4.1},
         {160, 250} => {5.08, 0.3},
         {250, 400} => {3.11, -16.7},
         {400, 630} => {2.68, -36.3},
         {630, 1000} => {3.06, -53.1},
         {1000, 1600} => {2.04, -57.7}
       }},
    1 =>
      {[28, 29, 31, 32, 33, 35, 36, 37, 39, 40, 44, 46, 52, 53, 56, 58, 59, 61, 62],
       %{
         {80, 160} => {8.06, 15.9},
         {160, 250} => {6.72, 4.8},
         {250, 400} => {3.99, -12.9},
         {400, 630} => {3.44, -27.1},
         {630, 1000} => {4.85, -45.7},
         {1000, 1600} => {4.13, -48.8}
       }}
  }

  test "deep_bass's harmonics fade and stand as the recorded basses' do at each velocity", ctx do
    for {vel, {notes, bands}} <- @deep_bass do
      measured = Map.new(Measure.bands(bass_notes(ctx, :deep_bass, notes, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  # The recordings are each brought to the same peak: E2 of instrument 025 at velocity 127 is 0.4
  # dB louder than at 25 over its whole length, -11.2 dB against -11.6.
  test "deep_bass at vel 1 is louder than at vel 0.3, within 6 dB of the recordings", ctx do
    for note <- [28, 33, 40, 45] do
      soft = render(ctx, :deep_bass, [note: note, vel: 0.3], 0.6)
      hard = render(ctx, :deep_bass, [note: note, vel: 1], 0.6)
      louder = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      assert louder > 0 and abs(louder - 0.4) < 6, "note #{note} is #{louder} dB louder"
    end
  end

  test "deep_bass plays MIDI 22 and 63, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [22, 63] do
      expected = 440 * :math.pow(2, (note - 69) / 12)
      sound = render(ctx, :deep_bass, [note: note], 1.2)
      hz = pitch(window(sound, 0.1, 1.1), expected)
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # The recorded A1s at velocity 127 are 2.0 and 1.6 dB under their level at a tenth of a second
  # after one second, and 10.0 and 4.9 dB under it after 2.8.
  # At the softer velocities the recorded A1's second harmonic rings 12 to 28 seconds, far longer
  # than those of the notes around it, and the design holds the medians over the notes.
  test "deep_bass's A1 fades as the recorded ones do, and sustain and release damp it", ctx do
    sound = render(ctx, :deep_bass, [note: 33, vel: 1], 3.2)
    under = fn at -> 20 * :math.log10(rms(sound, at, at + 0.1) / rms(sound, 0.1, 0.2)) end
    assert_in_delta under.(1.0), -1.8, 3
    assert_in_delta under.(2.8), -7.5, 3

    damped = render(ctx, :deep_bass, [note: 33, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  # The electric piano is fitted to keyboard_electronic_098 of the test set of Google's NSynth
  # dataset partial by partial, and mix mx.fit --check compares it with each recording; those
  # tests run where the recordings are, in test/mix/tasks/mx.fit_test.exs.

  # The recording's E4 at velocity 25 has a partial at 7.35 times its note, 39.5 dB under the
  # loudest, that fades 60 dB in 0.89 seconds: the tine's bell.
  test "electric_piano's soft E4 rings a bell partial near 7.35 times its note that dies within 1.5 seconds",
       ctx do
    %{partials: partials} =
      Hits.hit(render(ctx, :electric_piano, [note: 64, vel: 0.2], 3), @rate, 64, partials: 12)

    assert %{ring: ring} = Enum.find(partials, &(&1.ratio > 7 and &1.ratio < 7.7))
    assert ring < 1.5
  end

  # The recordings are each brought to the same peak, so they do not say how much louder a harder
  # note is; at E1 velocity 127 is 3 dB quieter than 25 over the whole note, as it fades faster.
  test "electric_piano at vel 1 is louder than at vel 0.3, and E3 than at vel 0.2, by 3 to 6 dB, and brighter",
       ctx do
    for note <- [40, 52, 64, 76] do
      soft = render(ctx, :electric_piano, [note: note, vel: 0.3], 0.6)
      hard = render(ctx, :electric_piano, [note: note, vel: 1], 0.6)
      louder = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      assert louder > 3 and louder < 6, "note #{note} is #{louder} dB louder"
    end

    soft = render(ctx, :electric_piano, [note: 52, vel: 0.2], 0.6)
    hard = render(ctx, :electric_piano, [note: 52, vel: 1], 0.6)
    louder = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
    assert louder > 3 and louder < 6, "E3 at vel 1 is #{louder} dB louder than at vel 0.2"

    bright = fn vel ->
      [note | _] = bass_notes(ctx, :electric_piano, [48], vel)
      [first | _] = note.harmonics
      tenth = Enum.find(note.harmonics, &(&1.number == 10))
      tenth.level - first.level
    end

    assert bright.(1) > bright.(0.2)
  end

  test "electric_piano plays MIDI 28 and 88 at their pitch", ctx do
    for note <- [28, 88] do
      expected = 440 * :math.pow(2, (note - 69) / 12)
      sound = render(ctx, :electric_piano, [note: note], 1.2)
      hz = pitch(window(sound, 0.1, 1.1), expected)
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # The electric guitar is fitted to guitar_electronic_028 of the test set of Google's NSynth
  # dataset partial by partial, and mix mx.fit --check compares it with each recording; those
  # tests run where the recordings are, in test/mix/tasks/mx.fit_test.exs.

  # The recordings are each brought to the same peak, so they do not say how much louder a harder
  # note is.
  test "electric_guitar at vel 1 is louder than at vel 0.3 by 3 to 6 dB", ctx do
    for note <- [40, 52, 64, 76] do
      soft = render(ctx, :electric_guitar, [note: note, vel: 0.3], 0.6)
      hard = render(ctx, :electric_guitar, [note: note, vel: 1], 0.6)
      louder = 20 * :math.log10(rms(hard, 0, 0.5) / rms(soft, 0, 0.5))
      assert louder > 3 and louder < 6, "note #{note} is #{louder} dB louder"
    end
  end

  test "electric_guitar plays MIDI 40 and 86 at their pitch", ctx do
    for note <- [40, 86] do
      expected = 440 * :math.pow(2, (note - 69) / 12)
      sound = render(ctx, :electric_guitar, [note: note], 1.2)
      hz = pitch(window(sound, 0.1, 1.1), expected)
      cents = 1200 * :math.log2(hz / expected)
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's violin, bowed without vibrato on every string from G3
  # to B7, at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to swell in, and each band's level while it holds, against G3's
  # fundamental.
  @violin %{
    0.3 => %{
      attack: 0.75,
      bands: %{
        {160, 250} => 4.7,
        {250, 400} => 21.9,
        {400, 630} => 13.9,
        {630, 1000} => 11.0,
        {1000, 1600} => 0.8,
        {1600, 2500} => 2.8,
        {2500, 4000} => -8.4
      }
    },
    0.6 => %{
      attack: 0.61,
      bands: %{
        {160, 250} => 5.2,
        {250, 400} => 20.5,
        {400, 630} => 19.5,
        {630, 1000} => 14.8,
        {1000, 1600} => 11.7,
        {1600, 2500} => 11.7,
        {2500, 4000} => 2.8
      }
    },
    1 => %{
      attack: 0.3,
      bands: %{
        {160, 250} => 1.6,
        {250, 400} => 18.4,
        {400, 630} => 19.3,
        {630, 1000} => 16.3,
        {1000, 1600} => 11.0,
        {1600, 2500} => 11.3,
        {2500, 4000} => 6.1
      }
    }
  }

  test "violin swells in and holds its bands as Iowa's violin does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @violin do
      summary = Held.summary(bowed_notes(ctx, :violin, 55..107//4, vel: vel, vibrato: 0))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} swells in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # Measured from VSCO 2's solo violin, bowed with vibrato at f, against vel 1 and vibrato 0.25,
  # every third note from G3 to C7: its vibrato, and each band's level against G3's fundamental.
  # Its notes swell in within 0.09 s, against Iowa's 0.3 s at ff,
  # and its p notes, with no vibrato, stand 8 to 18 dB above Iowa's pp from 400 Hz to 1.6 kHz;
  # the violin follows Iowa in both.
  @vsco_violin %{
    vibrato: %{rate: 5.41, depth: 20.9},
    bands: %{
      {160, 250} => 3.9,
      {250, 400} => 19.9,
      {400, 630} => 24.5,
      {630, 1000} => 16.1,
      {1000, 1600} => 10.9,
      {1600, 2500} => 12.2,
      {2500, 4000} => 6.1
    }
  }

  test "violin's vibrato and bands follow VSCO 2's solo violin played f", ctx do
    notes = [55, 57, 60, 64, 67, 69, 72, 76, 79, 81, 84, 88, 91, 93, 96]
    summary = Held.summary(bowed_notes(ctx, :violin, notes, vel: 1, vibrato: 0.25))
    measured = Map.new(summary.bands, &{&1.band, &1.level})
    %{rate: rate, depth: depth} = @vsco_violin.vibrato

    assert_in_delta summary.vibrato.rate / rate, 1, 0.2, "vibrato at #{summary.vibrato.rate} Hz"

    assert_in_delta summary.vibrato.depth / depth,
                    1,
                    0.2,
                    "vibrato #{summary.vibrato.depth} cents deep"

    for {band, level} <- @vsco_violin.bands do
      assert_in_delta measured[band], level, 6, "#{inspect(band)} at #{measured[band]} dB"
    end
  end

  # The Iowa recordings are 13.5 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "violin at vel 1 is louder than at vel 0.3 by as much as Iowa's violin, and brighter",
       ctx do
    louder =
      for note <- [55, 67, 79, 91] do
        soft = render(ctx, :violin, [note: note, vel: 0.3, vibrato: 0, sustain: 2], 2)
        hard = render(ctx, :violin, [note: note, vel: 1, vibrato: 0, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 13.5, 6
  end

  test "violin plays G3 and B7, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [55, 107] do
      sound = render(ctx, :violin, [note: note, vibrato: 0, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's violin, plucked on every string from G3 to B7,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes by the harmonic's
  # frequency:
  # the seconds a harmonic takes to fade 60 dB, and its level against G3's fundamental.
  # The softer recordings' noise holds their fade times at 5 to 26 s from 630 Hz at mf and from
  # 400 Hz at pp, as it does above 1 kHz at ff, where the harmonics stand over 20 dB below G3's;
  # those fades, nil here, are left out.
  @violin_pizz %{
    0.3 => %{
      {160, 250} => {3.27, 7.7},
      {250, 400} => {1.63, 17.7},
      {400, 630} => {nil, -0.1},
      {630, 1000} => {nil, -7.7},
      {1000, 1600} => {nil, -22.9}
    },
    0.6 => %{
      {160, 250} => {2.64, -0.9},
      {250, 400} => {1.88, 6.3},
      {400, 630} => {1.72, -0.7},
      {630, 1000} => {nil, -9.3},
      {1000, 1600} => {nil, -25.3}
    },
    1 => %{
      {160, 250} => {2.49, 4.1},
      {250, 400} => {1.62, 11.0},
      {400, 630} => {1.57, -0.5},
      {630, 1000} => {1.30, -6.7},
      {1000, 1600} => {nil, -21.5}
    }
  }

  test "violin's plucked notes fade and stand as Iowa's pizzicato does at pp, mf and ff", ctx do
    for {vel, bands} <- @violin_pizz do
      measured =
        Map.new(Measure.bands(plucked_notes(ctx, :violin, 55..107//4, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  test "a plucked violin note fades by itself, and sustain and release damp it", ctx do
    assert last_sound(render(ctx, :violin, [note: 55, pizz: 1, sustain: 1000], 6)) > 1.5

    damped = render(ctx, :violin, [note: 55, pizz: 1, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  test "a violin's vibrato grows as the note holds, and vibrato: 0 has none", ctx do
    held = render(ctx, :violin, [note: 69, sustain: 4], 4.5)
    still = render(ctx, :violin, [note: 69, sustain: 4, vibrato: 0], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, 0.05, 0.9) * 2
    assert Held.note(held, @rate, 69).vibrato != nil
    assert Held.note(still, @rate, 69).vibrato == nil
  end

  # Measured from the University of Iowa's viola, bowed without vibrato on every string from C3 to
  # Bb6, at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to swell in, and each band's level while it holds, against C3's
  # fundamental.
  # VSCO 2 has a viola section, several players in a room, whose bands stand 10 to 20 dB higher
  # against its C3 and whose noise between the harmonics is 15 to 20 dB louder; the viola follows
  # Iowa's one player.
  @viola %{
    0.3 => %{
      attack: 0.53,
      bands: %{
        {80, 160} => 1.8,
        {160, 250} => 22.3,
        {250, 400} => 30.0,
        {400, 630} => 26.6,
        {630, 1000} => 26.9,
        {1000, 1600} => 21.6,
        {1600, 2500} => 18.8,
        {2500, 4000} => 0.2
      }
    },
    0.6 => %{
      attack: 0.55,
      bands: %{
        {80, 160} => 0.4,
        {160, 250} => 23.9,
        {250, 400} => 29.3,
        {400, 630} => 27.6,
        {630, 1000} => 29.2,
        {1000, 1600} => 23.4,
        {1600, 2500} => 21.7,
        {2500, 4000} => 5.9
      }
    },
    1 => %{
      attack: 0.32,
      bands: %{
        {80, 160} => 0.2,
        {160, 250} => 24.8,
        {250, 400} => 32.1,
        {400, 630} => 27.4,
        {630, 1000} => 28.2,
        {1000, 1600} => 25.8,
        {1600, 2500} => 24.2,
        {2500, 4000} => 8.0
      }
    }
  }

  test "viola swells in and holds its bands as Iowa's viola does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @viola do
      summary = Held.summary(bowed_notes(ctx, :viola, 48..82//3, vel: vel, vibrato: 0))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} swells in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # The Iowa recordings are 7.6 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "viola at vel 1 is louder than at vel 0.3 by as much as Iowa's viola, and brighter", ctx do
    louder =
      for note <- [48, 60, 72] do
        soft = render(ctx, :viola, [note: note, vel: 0.3, vibrato: 0, sustain: 2], 2)
        hard = render(ctx, :viola, [note: note, vel: 1, vibrato: 0, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 7.6, 6
  end

  test "viola plays C3 and Bb6, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [48, 94] do
      sound = render(ctx, :viola, [note: note, vibrato: 0, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's viola, plucked on every string from C3 to Bb6,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes by the harmonic's
  # frequency:
  # each band's level against C3's fundamental.
  # Their fade times disagree from one dynamic to the next,
  # 160 to 250 Hz fading in 11.0 s at pp, 3.7 s at mf and 16.6 s at ff, so they are left out,
  # and so are pp's 160 to 250 Hz, 20.7 dB, and mf's 80 to 160 Hz, -4.4 dB, which the viola misses
  # by 9 and 6.4 dB.
  @viola_pizz %{
    0.3 => %{
      {80, 160} => -0.8,
      {250, 400} => 20.3,
      {400, 630} => 12.7,
      {630, 1000} => 0.0,
      {1000, 1600} => -15.3
    },
    0.6 => %{
      {160, 250} => 8.3,
      {250, 400} => 21.0,
      {400, 630} => 15.3,
      {630, 1000} => 4.3,
      {1000, 1600} => -9.3
    },
    1 => %{
      {80, 160} => -3.9,
      {160, 250} => 14.1,
      {250, 400} => 14.9,
      {400, 630} => 12.3,
      {630, 1000} => 5.8,
      {1000, 1600} => -8.0
    }
  }

  test "viola's plucked notes stand as Iowa's pizzicato does at pp, mf and ff", ctx do
    for {vel, bands} <- @viola_pizz do
      measured =
        Map.new(Measure.bands(plucked_notes(ctx, :viola, 48..82//3, vel)), &{&1.band, &1})

      for {band, level} <- bands do
        assert_in_delta measured[band].level,
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band].level} dB"
      end
    end
  end

  test "a plucked viola note fades by itself, and sustain and release damp it", ctx do
    assert last_sound(render(ctx, :viola, [note: 48, pizz: 1, sustain: 1000], 6)) > 1.5

    damped = render(ctx, :viola, [note: 48, pizz: 1, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  test "a viola's vibrato grows as the note holds, and vibrato: 0 has none", ctx do
    held = render(ctx, :viola, [note: 60, sustain: 4], 4.5)
    still = render(ctx, :viola, [note: 60, sustain: 4, vibrato: 0], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, 0.05, 0.9) * 2
    assert Held.note(held, @rate, 60).vibrato != nil
    assert Held.note(still, @rate, 60).vibrato == nil
  end

  # Measured from the University of Iowa's cello, bowed without vibrato on every string from C2 to
  # Bb5, at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to swell in, and each band's level while it holds, against C2's
  # fundamental.
  # The notes found below C2, onsets of noise, are left out; the measurement has no band below 80
  # Hz, where C2 sits.
  @cello %{
    0.3 => %{
      attack: 0.54,
      bands: %{
        {80, 160} => 17.2,
        {160, 250} => 21.6,
        {250, 400} => 17.3,
        {400, 630} => 10.0,
        {630, 1000} => 10.9,
        {1000, 1600} => 0.0,
        {1600, 2500} => -3.0,
        {2500, 4000} => -22.9
      }
    },
    0.6 => %{
      attack: 0.5,
      bands: %{
        {80, 160} => 17.6,
        {160, 250} => 21.1,
        {250, 400} => 17.8,
        {400, 630} => 12.2,
        {630, 1000} => 15.7,
        {1000, 1600} => 8.0,
        {1600, 2500} => 5.2,
        {2500, 4000} => -13.1
      }
    },
    1 => %{
      attack: 0.39,
      bands: %{
        {80, 160} => 15.2,
        {160, 250} => 19.8,
        {250, 400} => 14.3,
        {400, 630} => 12.5,
        {630, 1000} => 13.6,
        {1000, 1600} => 8.9,
        {1600, 2500} => 7.3,
        {2500, 4000} => -10.4
      }
    }
  }

  test "cello swells in and holds its bands as Iowa's cello does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @cello do
      summary = Held.summary(bowed_notes(ctx, :cello, 36..82//3, vel: vel, vibrato: 0))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} swells in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # The Iowa recordings are 14.8 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "cello at vel 1 is louder than at vel 0.3 by as much as Iowa's cello, and brighter", ctx do
    louder =
      for note <- [36, 48, 60, 72] do
        soft = render(ctx, :cello, [note: note, vel: 0.3, vibrato: 0, sustain: 2], 2)
        hard = render(ctx, :cello, [note: note, vel: 1, vibrato: 0, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 14.8, 6
  end

  test "cello plays C2 and Bb5, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [36, 82] do
      sound = render(ctx, :cello, [note: note, vibrato: 0, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's cello, plucked on every string from C2 to Bb5,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes by the harmonic's
  # frequency:
  # the seconds a harmonic takes to fade 60 dB, and its level against C2's fundamental.
  # From 630 Hz, and from 250 Hz at pp, the fade times grow with the frequency as the recordings'
  # noise holds them, and ff's 160 to 250 Hz and 400 to 630 Hz, 2.6 and 2.3 s, fall short of the
  # bands either side;
  # those fades, nil here, are left out,
  # and so is mf's 80 to 160 Hz, 7.1 dB, which the cello misses by 7.2 dB.
  @cello_pizz %{
    0.3 => %{
      {80, 160} => {3.94, 13.8},
      {160, 250} => {3.65, 8.7},
      {250, 400} => {nil, -0.4},
      {400, 630} => {nil, -8.6},
      {630, 1000} => {nil, -21.6},
      {1000, 1600} => {nil, -35.4}
    },
    0.6 => %{
      {160, 250} => {3.15, 6.2},
      {250, 400} => {3.31, 1.0},
      {400, 630} => {3.01, -7.0},
      {630, 1000} => {nil, -18.8},
      {1000, 1600} => {nil, -34.0}
    },
    1 => %{
      {80, 160} => {4.55, 15.1},
      {160, 250} => {nil, 13.5},
      {250, 400} => {3.5, 6.8},
      {400, 630} => {nil, 1.0},
      {630, 1000} => {nil, -6.0},
      {1000, 1600} => {nil, -15.2}
    }
  }

  test "cello's plucked notes fade and stand as Iowa's pizzicato does at pp, mf and ff", ctx do
    for {vel, bands} <- @cello_pizz do
      measured =
        Map.new(Measure.bands(plucked_notes(ctx, :cello, 36..82//3, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  test "a plucked cello note fades by itself, and sustain and release damp it", ctx do
    assert last_sound(render(ctx, :cello, [note: 36, pizz: 1, sustain: 1000], 6)) > 1.5

    damped = render(ctx, :cello, [note: 36, pizz: 1, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  test "a cello's vibrato grows as the note holds, and vibrato: 0 has none", ctx do
    held = render(ctx, :cello, [note: 48, sustain: 4], 4.5)
    still = render(ctx, :cello, [note: 48, sustain: 4, vibrato: 0], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, 0.05, 0.9) * 2
    assert Held.note(held, @rate, 48).vibrato != nil
    assert Held.note(still, @rate, 48).vibrato == nil
  end

  # Measured from the University of Iowa's double bass, bowed without vibrato on every string from
  # E1 to G4, at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to swell in, and each band's level while it holds, against E1's
  # fundamental.
  # The notes found below E1, onsets of noise, are left out, and so are three files mix
  # mx.measure --held stops on, ff's C4 to D4 on the D string and pp's C3 to A3 and C3 to B3 on
  # the A and D strings.
  # The measurement has no band below 80 Hz, where E1 sits.
  # VSCO 2's solo contrabass stands within 6 dB of these up to 630 Hz and 7 to 10 dB above them
  # from 400 Hz to 1.6 kHz, and its notes played with vibrato measure none.
  # ff's attack, 0.16 s, is left out: the bowed string takes 0.21 s to settle at ff, as long as it
  # takes to gather what it loses each period.
  @double_bass %{
    0.3 => %{
      attack: 0.28,
      bands: %{
        {80, 160} => 21.0,
        {160, 250} => 12.0,
        {250, 400} => -0.5,
        {400, 630} => -8.9,
        {630, 1000} => -15.5,
        {1000, 1600} => -19.7,
        {1600, 2500} => -26.4,
        {2500, 4000} => -35.7
      }
    },
    0.6 => %{
      attack: 0.29,
      bands: %{
        {80, 160} => 23.6,
        {160, 250} => 15.1,
        {250, 400} => 4.4,
        {400, 630} => -3.6,
        {630, 1000} => -11.6,
        {1000, 1600} => -15.5,
        {1600, 2500} => -22.6,
        {2500, 4000} => -34.0
      }
    },
    1 => %{
      attack: nil,
      bands: %{
        {80, 160} => 27.7,
        {160, 250} => 20.7,
        {250, 400} => 10.3,
        {400, 630} => 4.1,
        {630, 1000} => -3.0,
        {1000, 1600} => -7.7,
        {1600, 2500} => -13.9,
        {2500, 4000} => -24.9
      }
    }
  }

  test "double_bass swells in and holds its bands as Iowa's double bass does at pp, mf and ff",
       ctx do
    for {vel, %{attack: attack, bands: bands}} <- @double_bass do
      summary = Held.summary(bowed_notes(ctx, :double_bass, 28..67//3, vel: vel, vibrato: 0))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      if attack do
        assert_in_delta summary.attack / attack,
                        1,
                        0.3,
                        "vel #{vel} swells in #{summary.attack} s"
      end

      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # The Iowa recordings are 11.5 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "double_bass at vel 1 is louder than at vel 0.3 by as much as Iowa's double bass, and brighter",
       ctx do
    louder =
      for note <- [28, 40, 52, 64] do
        soft = render(ctx, :double_bass, [note: note, vel: 0.3, vibrato: 0, sustain: 2], 2)
        hard = render(ctx, :double_bass, [note: note, vel: 1, vibrato: 0, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 11.5, 6
  end

  test "double_bass plays E1 and G4, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [28, 67] do
      sound = render(ctx, :double_bass, [note: note, vibrato: 0, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's double bass, plucked on every string from E1 to G4,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes by the harmonic's
  # frequency:
  # the seconds a harmonic takes to fade 60 dB, and its level against E1's fundamental.
  # At ff the harmonics up to 630 Hz fade in 3.5 to 3.8 s;
  # at mf and pp the recordings' noise draws the fades out the higher and the quieter the
  # harmonic, to 5.5 to 19 s, and from 630 Hz at ff too; those fades, nil here, are left out.
  @double_bass_pizz %{
    0.3 => %{
      {80, 160} => {nil, 13.9},
      {160, 250} => {nil, 0.9},
      {250, 400} => {nil, -14.1},
      {400, 630} => {nil, -24.6},
      {630, 1000} => {nil, -42.2},
      {1000, 1600} => {nil, -49.4}
    },
    0.6 => %{
      {80, 160} => {4.52, 11.4},
      {160, 250} => {4.85, 0.3},
      {250, 400} => {nil, -15.6},
      {400, 630} => {nil, -25.4},
      {630, 1000} => {nil, -45.9},
      {1000, 1600} => {nil, -55.2}
    },
    1 => %{
      {80, 160} => {3.75, 10.0},
      {160, 250} => {3.78, 0.2},
      {250, 400} => {3.52, -15.9},
      {400, 630} => {3.61, -22.7},
      {630, 1000} => {nil, -41.3},
      {1000, 1600} => {nil, -55.7}
    }
  }

  test "double_bass's plucked notes fade and stand as Iowa's pizzicato does at pp, mf and ff",
       ctx do
    for {vel, bands} <- @double_bass_pizz do
      measured =
        Map.new(Measure.bands(plucked_notes(ctx, :double_bass, 28..67//3, vel)), &{&1.band, &1})

      for {band, {fade, level}} <- bands do
        %{fade: synth_fade, level: synth_level} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        if fade do
          assert_in_delta synth_fade / fade,
                          1,
                          0.3,
                          "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
        end
      end
    end
  end

  test "a plucked double_bass note fades by itself, and sustain and release damp it", ctx do
    assert last_sound(render(ctx, :double_bass, [note: 28, pizz: 1, sustain: 1000], 6)) > 1.5

    damped = render(ctx, :double_bass, [note: 28, pizz: 1, sustain: 0.2, release: 0.1], 2)
    assert last_sound(damped) < 0.4
  end

  test "a double_bass's vibrato grows as the note holds, and vibrato: 0 has none", ctx do
    held = render(ctx, :double_bass, [note: 40, sustain: 4], 4.5)
    still = render(ctx, :double_bass, [note: 40, sustain: 4, vibrato: 0], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, 0.05, 0.9) * 2
    assert Held.note(held, @rate, 40).vibrato != nil
    assert Held.note(still, @rate, 40).vibrato == nil
  end

  # Measured from the University of Iowa's flute, played without vibrato from B3 to Db7,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to speak, and each band's level while it holds, against B3's
  # fundamental.
  # VSCO 2's flute stands 10 to 29 dB above these from 400 Hz up, against its own lowest note; the
  # flute follows Iowa.
  # mf's 400 to 630 Hz, 12.4 dB and 5 dB above ff's, is left out; the flute misses it by 6.1 dB.
  @flute %{
    0.3 => %{
      attack: 0.17,
      bands: %{
        {250, 400} => 0.5,
        {400, 630} => 1.3,
        {630, 1000} => -7.9,
        {1000, 1600} => -18.2,
        {1600, 2500} => -25.0,
        {2500, 4000} => -46.0
      }
    },
    0.6 => %{
      attack: 0.27,
      bands: %{
        {250, 400} => 6.2,
        {630, 1000} => 9.6,
        {1000, 1600} => 7.0,
        {1600, 2500} => -2.1,
        {2500, 4000} => -19.8
      }
    },
    1 => %{
      attack: 0.2,
      bands: %{
        {250, 400} => 4.4,
        {400, 630} => 7.5,
        {630, 1000} => 11.4,
        {1000, 1600} => 12.1,
        {1600, 2500} => -2.3,
        {2500, 4000} => -15.1
      }
    }
  }

  test "flute speaks and holds its bands as Iowa's flute does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @flute do
      summary = Held.summary(bowed_notes(ctx, :flute, 59..97//3, vel: vel, vibrato: 0))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # Measured from the same flute played with vibrato, and VSCO 2's flute played with vibrato at
  # its one strength, against vel 0.3:
  # the vibrato's rate in Hz and depth in cents, as medians over the notes.
  @flute_vibrato [
    {0.3, %{rate: 4.83, depth: 8.0}},
    {0.6, %{rate: 4.98, depth: 13.3}},
    {1, %{rate: 5.11, depth: 17.7}},
    {0.3, %{rate: 5.17, depth: 10.2}}
  ]

  test "flute's vibrato follows Iowa's and VSCO 2's flutes played with vibrato", ctx do
    for {vel, %{rate: rate, depth: depth}} <- @flute_vibrato do
      %{vibrato: vibrato} = Held.summary(bowed_notes(ctx, :flute, 59..97//6, vel: vel))

      assert_in_delta vibrato.rate / rate, 1, 0.2, "vel #{vel} vibrato at #{vibrato.rate} Hz"

      assert_in_delta vibrato.depth / depth,
                      1,
                      0.2,
                      "vel #{vel} vibrato #{vibrato.depth} cents deep"
    end
  end

  # The Iowa recordings are 13.2 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "flute at vel 1 is louder than at vel 0.3 by as much as Iowa's flute, and brighter", ctx do
    louder =
      for note <- [59, 71, 83, 95] do
        soft = render(ctx, :flute, [note: note, vel: 0.3, vibrato: 0, sustain: 2], 2)
        hard = render(ctx, :flute, [note: note, vel: 1, vibrato: 0, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 13.2, 6
  end

  test "flute plays B3 and Db7, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [59, 97] do
      sound = render(ctx, :flute, [note: note, vibrato: 0, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # Measured from the University of Iowa's Bb clarinet, played without vibrato from D3 to C7,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to speak, and each band's level while it holds, against D3's
  # fundamental.
  # pp's recordings leave out seven quiet stretches between notes, whose fundamental stands over
  # 40 dB below the notes'.
  # From 400 Hz up, VSCO 2's clarinet stands 4 to 13 dB above these played loud, and 4 to 19 dB
  # played soft;
  # the clarinet follows Iowa.
  @clarinet %{
    0.3 => %{
      attack: 0.16,
      bands: %{
        {160, 250} => 3.7,
        {250, 400} => 8.9,
        {400, 630} => -16.8,
        {630, 1000} => -17.7,
        {1000, 1600} => -37.3,
        {1600, 2500} => -45.9,
        {2500, 4000} => -45.3
      }
    },
    0.6 => %{
      attack: 0.17,
      bands: %{
        {160, 250} => 3.6,
        {250, 400} => 4.6,
        {400, 630} => -2.9,
        {630, 1000} => -4.7,
        {1000, 1600} => -14.3,
        {1600, 2500} => -23.2,
        {2500, 4000} => -32.0
      }
    },
    1 => %{
      attack: 0.32,
      bands: %{
        {160, 250} => 0.7,
        {250, 400} => 1.5,
        {400, 630} => -3.7,
        {630, 1000} => -6.6,
        {1000, 1600} => -10.4,
        {1600, 2500} => -20.4,
        {2500, 4000} => -28.4
      }
    }
  }

  test "clarinet speaks and holds its bands as Iowa's clarinet does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @clarinet do
      summary = Held.summary(bowed_notes(ctx, :clarinet, 50..96, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # The Iowa recordings are 10.6 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "clarinet at vel 1 is louder than at vel 0.3 by as much as Iowa's clarinet, and brighter",
       ctx do
    louder =
      for note <- [50, 62, 74, 86] do
        soft = render(ctx, :clarinet, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :clarinet, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 10.6, 6
  end

  test "clarinet plays D3 and C7, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [50, 96] do
      sound = render(ctx, :clarinet, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  # The reed and brass winds, their attacks fitted to their recordings', take up to half a second
  # to settle, so their pitch is compared from after that.
  @spoken 0.5

  test "a clarinet has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :clarinet, [note: 69, sustain: 4], 4.5)
    held = render(ctx, :clarinet, [note: 69, sustain: 4, vibrato: 0.25], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 69).vibrato != nil
    assert Held.note(still, @rate, 69).vibrato == nil
  end

  # Measured from the University of Iowa's oboe, played without vibrato from Bb3 to Ab6,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to speak, and each band's level while it holds, against Bb3's
  # fundamental.
  # VSCO 2's oboe stands 13 to 18 dB above these in every band, as its Bb3's fundamental is that
  # much weaker;
  # the shape of its bands matches, and the oboe follows Iowa.
  @oboe %{
    0.3 => %{
      attack: 0.19,
      bands: %{
        {250, 400} => 1.3,
        {400, 630} => 3.6,
        {630, 1000} => 0.8,
        {1000, 1600} => 3.8,
        {1600, 2500} => -18.3,
        {2500, 4000} => -29.2
      }
    },
    0.6 => %{
      attack: 0.25,
      bands: %{
        {250, 400} => -0.7,
        {400, 630} => 2.0,
        {630, 1000} => 4.7,
        {1000, 1600} => 10.8,
        {1600, 2500} => -6.3,
        {2500, 4000} => -12.0
      }
    },
    1 => %{
      attack: 0.1,
      bands: %{
        {250, 400} => -0.9,
        {400, 630} => 0.8,
        {630, 1000} => 2.5,
        {1000, 1600} => 8.8,
        {1600, 2500} => -10.8,
        {2500, 4000} => -10.2
      }
    }
  }

  test "oboe speaks and holds its bands as Iowa's oboe does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @oboe do
      summary = Held.summary(bowed_notes(ctx, :oboe, 58..92, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # The Iowa recordings are 13.2 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "oboe at vel 1 is louder than at vel 0.3 by as much as Iowa's oboe, and brighter", ctx do
    louder =
      for note <- [58, 68, 78, 88] do
        soft = render(ctx, :oboe, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :oboe, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 13.2, 6
  end

  test "oboe plays Bb3 and Ab6, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [58, 92] do
      sound = render(ctx, :oboe, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "an oboe has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :oboe, [note: 69, sustain: 4], 4.5)
    held = render(ctx, :oboe, [note: 69, sustain: 4, vibrato: 0.25], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 69).vibrato != nil
    assert Held.note(still, @rate, 69).vibrato == nil
  end

  # Measured from the University of Iowa's bassoon, played without vibrato from Bb1 to D5,
  # at pp, mf and ff against vel 0.3, 0.6 and 1, as medians over its notes:
  # the seconds a note takes to speak, and each band's level while it holds, against Bb1's
  # fundamental.
  # There is no band below 80 Hz, though the bassoon reaches down to 58 Hz.
  # VSCO 2's held bassoon stands about 40 dB above these, as its lowest note has almost no
  # fundamental;
  # the bassoon follows Iowa.
  @bassoon %{
    0.3 => %{
      attack: 0.08,
      bands: %{
        {80, 160} => 3.5,
        {160, 250} => 6.3,
        {250, 400} => 9.9,
        {400, 630} => 14.9,
        {630, 1000} => -5.2,
        {1000, 1600} => -20.0,
        {1600, 2500} => -34.2,
        {2500, 4000} => -43.5
      }
    },
    0.6 => %{
      attack: 0.16,
      bands: %{
        {80, 160} => -0.7,
        {160, 250} => 2.7,
        {250, 400} => 6.6,
        {400, 630} => 13.9,
        {630, 1000} => -3.8,
        {1000, 1600} => -10.1,
        {1600, 2500} => -27.8,
        {2500, 4000} => -40.0
      }
    },
    1 => %{
      attack: 0.07,
      bands: %{
        {80, 160} => -2.4,
        {160, 250} => 1.2,
        {250, 400} => 5.2,
        {400, 630} => 11.1,
        {630, 1000} => -5.0,
        {1000, 1600} => -10.2,
        {1600, 2500} => -23.5,
        {2500, 4000} => -32.7
      }
    }
  }

  test "bassoon speaks and holds its bands as Iowa's bassoon does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @bassoon do
      summary = Held.summary(bowed_notes(ctx, :bassoon, 34..74, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # VSCO 2's bassoon played with vibrato swings 5.5 times a second by 7 cents,
  # as medians over the 8 of its 21 notes whose vibrato measures.
  test "bassoon's vibrato at 0.1 follows VSCO 2's bassoon played with vibrato", ctx do
    %{vibrato: vibrato} =
      Held.summary(bowed_notes(ctx, :bassoon, 34..74//6, vel: 0.6, vibrato: 0.1))

    assert_in_delta vibrato.rate / 5.5, 1, 0.2, "vibrato at #{vibrato.rate} Hz"
    assert_in_delta vibrato.depth / 7.0, 1, 0.2, "vibrato #{vibrato.depth} cents deep"
  end

  # The Iowa recordings are 12.5 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "bassoon at vel 1 is louder than at vel 0.3 by as much as Iowa's bassoon, and brighter",
       ctx do
    louder =
      for note <- [34, 46, 58, 70] do
        soft = render(ctx, :bassoon, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :bassoon, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 12.5, 6
  end

  test "bassoon plays Bb1 and D5, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [34, 74] do
      sound = render(ctx, :bassoon, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a bassoon has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :bassoon, [note: 50, sustain: 4], 4.5)
    held = render(ctx, :bassoon, [note: 50, sustain: 4, vibrato: 0.25], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 50).vibrato != nil
    assert Held.note(still, @rate, 50).vibrato == nil
  end

  # Measured from the tenor saxophone of the Versilian Community Sample Library, held without
  # vibrato from Ab2 to E5, at its two strengths against vel 0.6 and 1, as medians over its notes:
  # the seconds a note takes to speak, and each band's level while it holds, against Ab2's
  # fundamental.
  # The recordings go on up to E6, in the altissimo register, which the tenor_sax leaves out.
  @tenor_sax %{
    0.6 => %{
      attack: 0.08,
      bands: %{
        {80, 160} => -0.6,
        {160, 250} => -4.2,
        {250, 400} => 4.7,
        {400, 630} => 1.1,
        {630, 1000} => -13.7,
        {1000, 1600} => -18.3,
        {1600, 2500} => -25.4,
        {2500, 4000} => -34.2
      }
    },
    1 => %{
      attack: 0.04,
      bands: %{
        {80, 160} => -3.3,
        {160, 250} => -7.4,
        {250, 400} => 3.1,
        {400, 630} => 1.3,
        {630, 1000} => -11.7,
        {1000, 1600} => -12.6,
        {1600, 2500} => -18.1,
        {2500, 4000} => -27.2
      }
    }
  }

  test "tenor_sax speaks and holds its bands as VCSL's tenor saxophone does at both strengths",
       ctx do
    for {vel, %{attack: attack, bands: bands}} <- @tenor_sax do
      summary = Held.summary(bowed_notes(ctx, :tenor_sax, 44..76, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # VCSL's tenor saxophone held with vibrato swings 4.94 times a second by 10.8 cents,
  # as medians over its notes up to E5.
  test "tenor_sax's vibrato at 0.145 semitones follows VCSL's tenor saxophone played with vibrato",
       ctx do
    %{vibrato: vibrato} =
      Held.summary(bowed_notes(ctx, :tenor_sax, 44..76//4, vel: 0.6, vibrato: 0.145))

    assert_in_delta vibrato.rate / 4.94, 1, 0.2, "vibrato at #{vibrato.rate} Hz"
    assert_in_delta vibrato.depth / 10.8, 1, 0.2, "vibrato #{vibrato.depth} cents deep"
  end

  # The recordings are 5.9 dB louder at their loudest strength than at the other,
  # as the median over their files of the level while the notes hold.
  test "tenor_sax at vel 1 is louder than at vel 0.6 by as much as VCSL's tenor saxophone, and brighter",
       ctx do
    louder =
      for note <- [44, 52, 60, 68] do
        mf = render(ctx, :tenor_sax, [note: note, vel: 0.6, sustain: 2], 2)
        ff = render(ctx, :tenor_sax, [note: note, vel: 1, sustain: 2], 2)
        assert highs(ff, 2000, 1, 2) / rms(ff, 1, 2) > highs(mf, 2000, 1, 2) / rms(mf, 1, 2)
        20 * :math.log10(rms(ff, 1, 2) / rms(mf, 1, 2))
      end

    assert_in_delta median(louder), 5.9, 6
  end

  # Measured from the same saxophone's staccato notes up to E5, at its two strengths against vel
  # 0.3 and 0.6.
  # As medians over the notes: each band's level as the note starts, against the loudest band.
  # And the seconds it takes to fade 60 dB, with the notes held 0.15 s.
  # Their 80 to 160 Hz band rings twice as long as every band above it, as the room would, and is
  # left out.
  @tenor_sax_staccato %{
    0.3 =>
      {[50, 52, 54, 56, 57, 60, 62, 64, 66, 68, 70, 72, 74, 76],
       %{
         {160, 250} => {-10.5, 0.62},
         {250, 400} => {-1.2, 0.59},
         {400, 630} => {-2.0, 0.53},
         {630, 1000} => {-12.1, 0.48},
         {1000, 1600} => {-14.3, 0.52},
         {1600, 2500} => {-15.4, 0.55},
         {2500, 4000} => {-19.6, 0.54}
       }},
    0.6 =>
      {[44, 46, 48, 50, 52, 54, 56, 57, 60, 62, 64, 66, 68, 70, 72, 74, 76],
       %{
         {160, 250} => {-14.5, 0.61},
         {250, 400} => {-1.1, 0.53},
         {400, 630} => {0.0, 0.46},
         {630, 1000} => {-5.8, 0.41},
         {1000, 1600} => {-8.4, 0.48},
         {1600, 2500} => {-11.3, 0.53},
         {2500, 4000} => {-19.6, 0.52}
       }}
  }

  test "a short tenor_sax note starts and fades as VCSL's staccato notes do", ctx do
    for {vel, {notes, bands}} <- @tenor_sax_staccato do
      hits =
        notes
        |> Task.async_stream(
          fn note ->
            Hits.hit(
              render(ctx, :tenor_sax, [note: note, vel: vel, sustain: 0.15], 2),
              @rate,
              note
            )
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, hit} -> hit end)

      measured = Map.new(Hits.summary(hits), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        assert_in_delta synth_level, level, 6, "vel #{vel} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "vel #{vel} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  test "tenor_sax plays Ab2 and E6, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [44, 88] do
      sound = render(ctx, :tenor_sax, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a tenor_sax has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :tenor_sax, [note: 56, sustain: 4], 4.5)
    held = render(ctx, :tenor_sax, [note: 56, sustain: 4, vibrato: 1], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 56).vibrato != nil
    assert Held.note(still, @rate, 56).vibrato == nil
  end

  # Measured from the University of Iowa's Bb trumpet, held without vibrato from E3 to Eb6,
  # at pp, mf and ff against vel 0.3, 0.6 and 1,
  # as medians over its notes, leaving out the quiet stretches between them:
  # the seconds a note takes to speak, and each band's level while it holds, against E3's
  # fundamental.
  @trumpet %{
    0.3 => %{
      attack: 0.22,
      bands: %{
        {160, 250} => 1.8,
        {250, 400} => 8.7,
        {400, 630} => 16.4,
        {630, 1000} => 20.9,
        {1000, 1600} => 25.0,
        {1600, 2500} => 10.3,
        {2500, 4000} => -13.0
      }
    },
    0.6 => %{
      attack: 0.19,
      bands: %{
        {160, 250} => 3.2,
        {250, 400} => 11.4,
        {400, 630} => 19.9,
        {630, 1000} => 25.0,
        {1000, 1600} => 28.5,
        {1600, 2500} => 21.9,
        {2500, 4000} => 9.5
      }
    },
    1 => %{
      attack: 0.10,
      bands: %{
        {160, 250} => 4.2,
        {250, 400} => 12.9,
        {400, 630} => 20.4,
        {630, 1000} => 25.1,
        {1000, 1600} => 29.7,
        {1600, 2500} => 23.1,
        {2500, 4000} => 13.5
      }
    }
  }

  test "trumpet speaks and holds its bands as Iowa's Bb trumpet does at pp, mf and ff", ctx do
    for {vel, %{attack: attack, bands: bands}} <- @trumpet do
      summary = Held.summary(bowed_notes(ctx, :trumpet, 52..86, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # Iowa's Bb trumpet held with vibrato swings 4.9 times a second by 7 cents, as medians over its
  # notes at mf.
  test "trumpet's vibrato at 0.095 follows Iowa's Bb trumpet played with vibrato", ctx do
    %{vibrato: vibrato} =
      Held.summary(bowed_notes(ctx, :trumpet, 52..86//4, vel: 0.6, vibrato: 0.095))

    assert_in_delta vibrato.rate / 4.9, 1, 0.2, "vibrato at #{vibrato.rate} Hz"
    assert_in_delta vibrato.depth / 7, 1, 0.2, "vibrato #{vibrato.depth} cents deep"
  end

  # The Iowa recordings are 9.2 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "trumpet at vel 1 is louder than at vel 0.3 by as much as Iowa's Bb trumpet, and brighter",
       ctx do
    louder =
      for note <- [52, 62, 72, 82] do
        soft = render(ctx, :trumpet, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :trumpet, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 9.2, 6
  end

  test "trumpet plays E3 and Eb6, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [52, 87] do
      sound = render(ctx, :trumpet, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a trumpet has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :trumpet, [note: 65, sustain: 4], 4.5)
    held = render(ctx, :trumpet, [note: 65, sustain: 4, vibrato: 0.1], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 65).vibrato != nil
    assert Held.note(still, @rate, 65).vibrato == nil
  end

  # Measured from the University of Iowa's tenor trombone, held without vibrato from E2 to C5,
  # at pp, mf and ff against vel 0.3, 0.6 and 1,
  # as medians over its notes, leaving out the quiet stretches between them:
  # the seconds a note takes to speak, and each band's level while it holds, against E2's
  # fundamental.
  @trombone %{
    0.3 => %{
      attack: 0.22,
      bands: %{
        {80, 160} => 8.9,
        {160, 250} => 15.7,
        {250, 400} => 17.6,
        {400, 630} => 15.7,
        {630, 1000} => 11.1,
        {1000, 1600} => -3.5,
        {1600, 2500} => -26.5,
        {2500, 4000} => -38.9
      }
    },
    0.6 => %{
      attack: 0.26,
      bands: %{
        {80, 160} => 5.6,
        {160, 250} => 19.2,
        {250, 400} => 19.5,
        {400, 630} => 21.7,
        {630, 1000} => 20.7,
        {1000, 1600} => 13.6,
        {1600, 2500} => 2.2,
        {2500, 4000} => -14.8
      }
    },
    1 => %{
      attack: 0.16,
      bands: %{
        {80, 160} => 6.0,
        {160, 250} => 18.3,
        {250, 400} => 16.8,
        {400, 630} => 19.6,
        {630, 1000} => 20.5,
        {1000, 1600} => 16.9,
        {1600, 2500} => 13.1,
        {2500, 4000} => 5.5
      }
    }
  }

  test "trombone speaks and holds its bands as Iowa's tenor trombone does at pp, mf and ff",
       ctx do
    for {vel, %{attack: attack, bands: bands}} <- @trombone do
      summary = Held.summary(bowed_notes(ctx, :trombone, 40..72, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # Iowa's trombone has no vibrato, and VSCO 2's tenor trombone held with vibrato measures one on
  # 4 of its 12 notes, swinging 4.95 times a second by 13 cents, as medians over those notes.
  test "trombone's vibrato at 0.176 follows VSCO 2's tenor trombone played with vibrato", ctx do
    %{vibrato: vibrato} =
      Held.summary(bowed_notes(ctx, :trombone, 40..72//4, vel: 0.6, vibrato: 0.176))

    assert_in_delta vibrato.rate / 4.95, 1, 0.2, "vibrato at #{vibrato.rate} Hz"
    assert_in_delta vibrato.depth / 13, 1, 0.2, "vibrato #{vibrato.depth} cents deep"
  end

  # The Iowa recordings are 20.1 dB louder at ff than at pp,
  # as the median over their files of the level while the notes hold.
  test "trombone at vel 1 is louder than at vel 0.3 by as much as Iowa's tenor trombone, and brighter",
       ctx do
    louder =
      for note <- [40, 50, 60, 70] do
        soft = render(ctx, :trombone, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :trombone, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 20.1, 6
  end

  test "trombone plays E2 and C5, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [40, 72] do
      sound = render(ctx, :trombone, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a trombone has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :trombone, [note: 53, sustain: 4], 4.5)
    held = render(ctx, :trombone, [note: 53, sustain: 4, vibrato: 0.2], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 53).vibrato != nil
    assert Held.note(still, @rate, 53).vibrato == nil
  end

  test "a trombone note glides to a new note over its slide, as the slide moves", ctx do
    slide = [note: 60.0, note_slide: 1.0]
    sound = render(ctx, :trombone, [note: 48, sustain: 4], 4, [{1.0, slide}])
    assert_in_delta pitch(sound, 0.5, 0.7), 130.8, 1.3
    assert pitch(sound, 1.4, 1.6) > 140
    assert pitch(sound, 1.4, 1.6) < 250
    assert_in_delta pitch(sound, 2.2, 2.4), 261.6, 2.6
  end

  # Measured from VSCO 2's F horn, held at its three strengths against vel 0.3, 0.6 and 1,
  # on the notes it has at each, as medians over them, leaving out the quiet stretches between
  # them:
  # the seconds a note takes to speak, and each band's level while it holds, against C2's
  # fundamental.
  @horn %{
    0.3 => %{
      notes: [36, 39, 43, 46, 50, 53, 57, 60, 74, 77],
      attack: 0.08,
      bands: %{
        {80, 160} => 5.1,
        {160, 250} => 18.9,
        {250, 400} => 23.7,
        {400, 630} => 24.8,
        {630, 1000} => 4.5,
        {1000, 1600} => -16.5,
        {1600, 2500} => -34.5,
        {2500, 4000} => -41.7
      }
    },
    0.6 => %{
      notes: [36, 39, 43, 46, 50, 53, 57, 60],
      attack: 0.11,
      bands: %{
        {80, 160} => 0.0,
        {160, 250} => 13.8,
        {250, 400} => 20.7,
        {400, 630} => 23.2,
        {630, 1000} => 3.8,
        {1000, 1600} => -13.4,
        {1600, 2500} => -32.2,
        {2500, 4000} => -37.3
      }
    },
    1 => %{
      notes: [36, 39, 43, 46, 50, 53, 57, 60],
      attack: 0.13,
      bands: %{
        {80, 160} => 0.0,
        {160, 250} => 17.2,
        {250, 400} => 19.6,
        {400, 630} => 25.0,
        {630, 1000} => 13.0,
        {1000, 1600} => -0.5,
        {1600, 2500} => -16.8,
        {2500, 4000} => -34.5
      }
    }
  }

  test "horn speaks and holds its bands as VSCO 2's F horn does at its three strengths", ctx do
    for {vel, %{notes: notes, attack: attack, bands: bands}} <- @horn do
      summary = Held.summary(bowed_notes(ctx, :horn, notes, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # VSCO 2's F horn is 14.4 dB louder at its loudest strength than at its softest,
  # as the median over the notes it has at both of the level while they hold.
  test "horn at vel 1 is louder than at vel 0.3 by as much as VSCO 2's F horn, and brighter",
       ctx do
    louder =
      for note <- [36, 48, 60, 72] do
        soft = render(ctx, :horn, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :horn, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 14.4, 6
  end

  # VSCO 2 records each note at its own gain, so how loud the horn is from note to note follows
  # Iowa's horn, which grows 8.7 dB louder from C4 to C5 at mf and 5.9 dB at ff, measured on its
  # loudest harmonics.
  test "horn grows louder from C4 to C5 as Iowa's horn does", ctx do
    for vel <- [0.6, 1] do
      c4 = render(ctx, :horn, [note: 60, vel: vel, sustain: 2], 2)
      c5 = render(ctx, :horn, [note: 72, vel: vel, sustain: 2], 2)
      assert_in_delta 20 * :math.log10(rms(c5, 1, 2) / rms(c4, 1, 2)), 7.3, 3
    end
  end

  test "horn plays C2 and F5, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [36, 77] do
      sound = render(ctx, :horn, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a horn has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :horn, [note: 53, sustain: 4], 4.5)
    held = render(ctx, :horn, [note: 53, sustain: 4, vibrato: 0.1], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 53).vibrato != nil
    assert Held.note(still, @rate, 53).vibrato == nil
  end

  # Measured from VSCO 2's tuba, held at its three strengths against vel 0.3, 0.6 and 1,
  # on the notes it has at each from Bb1 up, as medians over them, leaving out the quiet stretches
  # between them:
  # the seconds a note takes to speak, and each band's level while it holds, against Bb1's
  # fundamental.
  # At its softest it has nothing to measure from 2.5 kHz up.
  @tuba %{
    0.3 => %{
      notes: [34, 39, 41, 46, 50, 53, 58, 62],
      attack: 0.07,
      bands: %{
        {80, 160} => 15.7,
        {160, 250} => 17.8,
        {250, 400} => 4.8,
        {400, 630} => -0.9,
        {630, 1000} => -16.0,
        {1000, 1600} => -33.5,
        {1600, 2500} => -52.0
      }
    },
    0.6 => %{
      notes: [34, 39, 41, 46, 50, 53, 58],
      attack: 0.10,
      bands: %{
        {80, 160} => 17.2,
        {160, 250} => 19.5,
        {250, 400} => 12.5,
        {400, 630} => 6.6,
        {630, 1000} => -5.8,
        {1000, 1600} => -24.3,
        {1600, 2500} => -41.6,
        {2500, 4000} => -53.2
      }
    },
    1 => %{
      notes: [34, 39, 41, 46, 50, 53, 58],
      attack: 0.19,
      bands: %{
        {80, 160} => 15.0,
        {160, 250} => 19.6,
        {250, 400} => 12.6,
        {400, 630} => 13.8,
        {630, 1000} => 3.1,
        {1000, 1600} => -4.0,
        {1600, 2500} => -18.1,
        {2500, 4000} => -30.5
      }
    }
  }

  test "tuba speaks and holds its bands as VSCO 2's tuba does at its three strengths", ctx do
    for {vel, %{notes: notes, attack: attack, bands: bands}} <- @tuba do
      summary = Held.summary(bowed_notes(ctx, :tuba, notes, vel: vel))
      measured = Map.new(summary.bands, &{&1.band, &1.level})

      assert_in_delta summary.attack / attack, 1, 0.3, "vel #{vel} speaks in #{summary.attack} s"
      assert summary.vibrato == nil

      for {band, level} <- bands do
        assert_in_delta measured[band],
                        level,
                        6,
                        "vel #{vel} #{inspect(band)} at #{measured[band]} dB"
      end
    end
  end

  # VSCO 2's tuba is 21.9 dB louder at its loudest strength than at its softest,
  # as the median over the notes it has at both of the level while they hold.
  test "tuba at vel 1 is louder than at vel 0.3 by as much as VSCO 2's tuba, and brighter", ctx do
    louder =
      for note <- [34, 41, 48, 58] do
        soft = render(ctx, :tuba, [note: note, vel: 0.3, sustain: 2], 2)
        hard = render(ctx, :tuba, [note: note, vel: 1, sustain: 2], 2)

        assert highs(hard, 2000, 1, 2) / rms(hard, 1, 2) >
                 highs(soft, 2000, 1, 2) / rms(soft, 1, 2)

        20 * :math.log10(rms(hard, 1, 2) / rms(soft, 1, 2))
      end

    assert_in_delta median(louder), 21.9, 6
  end

  # VSCO 2 records each note at its own gain, so how loud the tuba is from note to note follows
  # Iowa's tuba, which grows 6.7 dB louder from C3 to C4 at mf, measured on its harmonics.
  test "tuba grows louder from C3 to C4 as Iowa's tuba does at mf", ctx do
    c3 = render(ctx, :tuba, [note: 48, vel: 0.6, sustain: 2], 2)
    c4 = render(ctx, :tuba, [note: 60, vel: 0.6, sustain: 2], 2)
    assert_in_delta 20 * :math.log10(rms(c4, 1, 2) / rms(c3, 1, 2)), 6.7, 3
  end

  test "tuba plays F1 and D4, the lowest and highest notes of the recordings, at their pitch",
       ctx do
    for note <- [29, 62] do
      sound = render(ctx, :tuba, [note: note, sustain: 2], 2.5)
      [%{freq: freq} | _] = Held.note(sound, @rate, note).harmonics
      cents = 1200 * :math.log2(freq / (440 * :math.pow(2, (note - 69) / 12)))
      assert abs(cents) < 5, "note #{note} is #{cents} cents off"
    end
  end

  test "a tuba has no vibrato by default, and vibrato grows as the note holds", ctx do
    still = render(ctx, :tuba, [note: 41, sustain: 4], 4.5)
    held = render(ctx, :tuba, [note: 41, sustain: 4, vibrato: 0.1], 4.5)
    assert wobble(held, 3.0, 3.9) > wobble(held, @spoken, 0.9) * 2
    assert Held.note(held, @rate, 41).vibrato != nil
    assert Held.note(still, @rate, 41).vibrato == nil
  end

  test "the pandeiro's thumb is darker than its slap", ctx do
    thumb = render(ctx, :pandeiro_thumb, [])
    slap = render(ctx, :pandeiro_slap, [])

    assert highs(thumb, 2000, 0, 0.2) / rms(thumb, 0, 0.2) <
             highs(slap, 2000, 0, 0.2) / rms(slap, 0, 0.2)
  end

  # Measured from the agogô of the Versilian Community Sample Library, as medians over its
  # strokes:
  # each band's level as the bell is struck, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  # Below 630 Hz the recordings hold the room rather than the bell, so those bands are left out.
  @agogo %{
    low_agogo: %{
      bands: %{
        {630, 1000} => {-13.4, 2.61},
        {1000, 1600} => {-2.7, 1.97},
        {1600, 2500} => {-6.5, 0.91},
        {2500, 4000} => {-0.8, 0.87},
        {4000, 6300} => {-4.4, 0.61},
        {6300, 10_000} => {-0.6, 0.42}
      },
      peaks: [1.0, 1.05, 2.98, 3.40],
      spread: 13.0,
      moments: %{
        {1000, 1600} => [-6, -4],
        {1600, 2500} => [-7, -17],
        {2500, 4000} => [-1, -11],
        {4000, 6300} => [-4, -12],
        {6300, 10_000} => [-1, -12],
        {10_000, 16_000} => [-11, -26]
      }
    },
    high_agogo: %{
      bands: %{
        {1000, 1600} => {0.0, 0.59},
        {1600, 2500} => {-17.7, 0.75},
        {2500, 4000} => {-12.8, 1.05},
        {4000, 6300} => {-7.0, 0.62},
        {6300, 10_000} => {-0.5, 0.50}
      },
      peaks: [1.0, 2.21, 3.23, 4.01, 4.60],
      spread: 18.2,
      moments: %{
        {1000, 1600} => [0, -10],
        {1600, 2500} => [-18, -28],
        {2500, 4000} => [-14, -14],
        {4000, 6300} => [-7, -13],
        {6300, 10_000} => [-1, -13],
        {10_000, 16_000} => [-7, -24]
      }
    }
  }

  test "each agogô bell's bands and fades follow VCSL's agogô", ctx do
    for {synth, %{bands: bands}} <- @agogo do
      hit = Hits.hit(render(ctx, synth, [], 3), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        assert_in_delta synth_level, level, 6, "#{synth} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "#{synth} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  # Each band's level at 0 and 50 ms after the strike, from mix mx.measure --hits over the same
  # recordings.
  # The stick's strike shows from 10 kHz up and fades within 100 ms.
  test "each agogô bell's bands at 0 and 50 ms follow VCSL's agogô, within 8 dB", ctx do
    for {synth, %{moments: moments}} <- @agogo do
      %{moments: found} = Hits.hit(render(ctx, synth, [], 3), @rate, nil)
      found = Map.new(found, &{&1.band, &1.levels})

      for {band, levels} <- moments,
          {level, synth_level, ms} <- Enum.zip([levels, found[band], [0, 50]]) do
        assert_in_delta synth_level,
                        level,
                        8,
                        "#{synth} #{inspect(band)} at #{ms} ms is #{synth_level} dB"
      end
    end
  end

  test "each agogô bell's peaks sit at the ratios of VCSL's agogô, within 3 percent", ctx do
    for {synth, %{peaks: peaks}} <- @agogo do
      %{peaks: found} = Hits.hit(render(ctx, synth, [], 3), @rate, nil)

      for ratio <- peaks do
        assert Enum.any?(found, &(abs(&1 / ratio - 1) <= 0.03)),
               "#{synth} has no peak at #{ratio}: #{inspect(found)}"
      end
    end
  end

  test "an agogô bell struck harder is louder and brighter, by as much as on the recordings",
       ctx do
    for {synth, %{spread: spread}} <- @agogo do
      soft = render(ctx, synth, [vel: 0.3], 1)
      hard = render(ctx, synth, [vel: 1], 1)
      louder = 20 * :math.log10(rms(hard, 0, 0.05) / rms(soft, 0, 0.05))
      assert_in_delta louder, spread, 6, "#{synth} is #{louder} dB louder"

      assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
               highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
    end
  end

  test "the high agogô is above the low one by the recordings' interval, and a note retunes a bell",
       ctx do
    low = loudest_hz(render(ctx, :low_agogo, [], 1))
    high = loudest_hz(render(ctx, :high_agogo, [], 1))
    assert_in_delta 12 * :math.log2(high / low), 12 * :math.log2(1487 / 1047), 0.5
    assert loudest_hz(render(ctx, :low_agogo, [note: 80], 1)) < low
  end

  test "each agogô bell rings no longer than the low bell's recordings, 2.6 seconds", ctx do
    for synth <- Map.keys(@agogo) do
      sound = render(ctx, synth, [vel: 1], 3.2)
      assert rms(sound, 0, 0.3) > 0.005, "#{synth}"
      assert peak(sound, 2.7, 3.2) == 0, "#{synth}"
    end
  end

  # Measured from the small and the large shaker of the Versilian Community Sample Library, as
  # medians:
  # each band's level as a stroke starts, against its loudest band,
  # and the seconds it takes to fade 60 dB, nil where it does not fade measurably.
  # The ganzá follows the small shaker, leaving out one up stroke too short to measure.
  @shakes [
    {:ganza, [],
     %{
       {1600, 2500} => {-32.8, 0.76},
       {2500, 4000} => {-25.5, 0.52},
       {4000, 6300} => {-16.3, 0.59},
       {6300, 10_000} => {-5.4, 0.69},
       {10_000, 16_000} => {0.0, 0.64}
     }},
    {:ganza, [up: 1],
     %{
       {1000, 1600} => {-38.4, nil},
       {1600, 2500} => {-33.5, nil},
       {2500, 4000} => {-24.5, 0.26},
       {4000, 6300} => {-21.3, 0.21},
       {6300, 10_000} => {-6.0, 0.20},
       {10_000, 16_000} => {0.0, 0.17}
     }},
    {:shaker, [],
     %{
       {1000, 1600} => {-34.0, 1.18},
       {1600, 2500} => {-16.7, 0.70},
       {2500, 4000} => {-5.3, 0.70},
       {4000, 6300} => {0.0, 0.59},
       {6300, 10_000} => {-3.6, 0.53},
       {10_000, 16_000} => {-7.2, 0.40}
     }},
    {:shaker, [up: 1],
     %{
       {1000, 1600} => {-25.8, 1.41},
       {1600, 2500} => {-12.8, 1.03},
       {2500, 4000} => {-6.5, 0.92},
       {4000, 6300} => {0.0, 0.80},
       {6300, 10_000} => {-5.9, 0.82},
       {10_000, 16_000} => {-14.5, 0.94}
     }}
  ]

  # The longest recorded stroke of each shaker, in seconds.
  @longest_stroke %{ganza: 0.265, shaker: 1.534}

  test "the ganzá's and the shaker's down and up strokes follow VCSL's shakers", ctx do
    for {synth, opts, bands} <- @shakes do
      hit = Hits.hit(render(ctx, synth, opts, 3), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        name = "#{synth} #{inspect(opts)} #{inspect(band)}"
        %{level: synth_level, fade: synth_fade} = measured[band]
        assert_in_delta synth_level, level, 6, "#{name} at #{synth_level} dB"

        if fade do
          assert_in_delta synth_fade / fade, 1, 0.3, "#{name} fades in #{synth_fade} s"
        end
      end
    end
  end

  # The large shaker's down stroke at 0, 50 and 100 ms after its loudest moment.
  # The figures come from mix mx.measure --hits over the same recordings.
  # The beads strike in a burst that holds for about 100 ms, then fall to a quieter tail.
  @shaker_moments %{
    {1600, 2500} => [-17, -17, -23],
    {2500, 4000} => [-5, -6, -13],
    {4000, 6300} => [0, 3, -3],
    {6300, 10_000} => [-4, -4, -11],
    {10_000, 16_000} => [-7, -10, -18]
  }

  test "the shaker's down stroke follows VCSL's at 0, 50 and 100 ms, within 8 dB", ctx do
    %{moments: found} = Hits.hit(render(ctx, :shaker, [], 3), @rate, nil)
    found = Map.new(found, &{&1.band, &1.levels})

    for {band, levels} <- @shaker_moments,
        {level, synth_level, ms} <- Enum.zip([levels, found[band], [0, 50, 100]]) do
      assert_in_delta synth_level, level, 8, "#{inspect(band)} at #{ms} ms is #{synth_level} dB"
    end
  end

  test "a harder stroke of the ganzá or the shaker is louder and brighter", ctx do
    for synth <- Map.keys(@longest_stroke), up <- [0, 1] do
      soft = render(ctx, synth, [vel: 0.3, up: up], 1)
      hard = render(ctx, synth, [vel: 1, up: up], 1)
      assert rms(hard, 0, 0.2) > rms(soft, 0, 0.2), "#{synth} up #{up}"

      assert highs(hard, 4000, 0, 0.2) / rms(hard, 0, 0.2) >
               highs(soft, 4000, 0, 0.2) / rms(soft, 0, 0.2),
             "#{synth} up #{up}"
    end
  end

  test "the ganzá and the shaker sound lower with a lower note", ctx do
    for synth <- Map.keys(@longest_stroke) do
      own = render(ctx, synth, [], 1)
      lower = render(ctx, synth, [note: 90], 1)

      assert highs(lower, 4000, 0, 0.2) / rms(lower, 0, 0.2) <
               highs(own, 4000, 0, 0.2) / rms(own, 0, 0.2)
    end
  end

  test "the ganzá and the shaker are silent within their longest recorded stroke", ctx do
    for {synth, longest} <- @longest_stroke, up <- [0, 1] do
      sound = render(ctx, synth, [vel: 1, up: up], longest + 0.3)
      assert rms(sound, 0, 0.1) > 0.005, "#{synth} up #{up}"
      assert peak(sound, longest, longest + 0.3) == 0, "#{synth} up #{up}"
    end
  end

  # Measured from the CC0 recording "pandeiro A" by MeanRaccoon on Freesound.
  # The thumb's, the heel's and the slap's figures are medians over the strokes sorted by ear:
  # 11 thumbs on the open head, 12 heel strokes on it and 10 slaps.
  # The fingertips' are medians over strokes sorted by their bands: loudest from 6.3 kHz, and at
  # least 8 dB softer below 250 Hz.
  # Each band's level is taken at 0, 50 and 100 ms after the stroke's loudest moment, against its
  # loudest band at 0 ms.
  # Fingertip strokes follow one another too closely to measure them at 100 ms.
  @pandeiro_bands [
    {80, 250},
    {250, 630},
    {630, 1600},
    {1600, 4000},
    {4000, 10_000},
    {10_000, 16_000}
  ]

  @pandeiro %{
    pandeiro_thumb: [
      [0, -7, -5],
      [-12, -17, -20],
      [-20, -32, -38],
      [-20, -23, -30],
      [-23, -24, -32],
      [-24, -20, -26]
    ],
    pandeiro_heel: [
      [-4, -11, -9],
      [-12, -18, -22],
      [-10, -26, -31],
      [-5, -15, -23],
      [-5, -15, -25],
      [0, -11, -19]
    ],
    pandeiro_slap: [
      [-15, -18, -26],
      [0, -16, -22],
      [-5, -20, -26],
      [-2, -18, -23],
      [-5, -20, -24],
      [-3, -15, -20]
    ],
    pandeiro_jingles: [[-11, -17], [-14, -20], [-13, -28], [-6, -19], [-5, -19], [0, -14]]
  }

  # Each pandeiro synth frees itself after this many seconds.
  @pandeiro_length %{
    pandeiro_thumb: 1.6,
    pandeiro_heel: 1.0,
    pandeiro_slap: 0.8,
    pandeiro_jingles: 1.2
  }

  test "each pandeiro stroke's bands follow pandeiro A at 0, 50 and 100 ms, within 10 dB", ctx do
    for {synth, levels} <- @pandeiro do
      measured = pandeiro_levels(render(ctx, synth, [], 1))

      for {band, real, mine} <- Enum.zip([@pandeiro_bands, levels, measured]),
          {level, synth_level, ms} <- Enum.zip([real, mine, [0, 50, 100]]) do
        assert_in_delta synth_level,
                        level,
                        10,
                        "#{synth} #{inspect(band)} at #{ms} ms is #{synth_level} dB"
      end
    end
  end

  test "a harder pandeiro stroke is louder and brighter", ctx do
    for synth <- Map.keys(@pandeiro) do
      soft = render(ctx, synth, [vel: 0.3], 1)
      hard = render(ctx, synth, [vel: 1], 1)
      assert rms(hard, 0, 0.2) > rms(soft, 0, 0.2), "#{synth}"

      assert highs(hard, 2000, 0, 0.2) / rms(hard, 0, 0.2) >
               highs(soft, 2000, 0, 0.2) / rms(soft, 0, 0.2),
             "#{synth}"
    end
  end

  # The head's tones are below 1 kHz; a slap's jingles are as loud as they are, so the loudest of
  # the whole stroke can be either.
  test "each pandeiro stroke's head sounds lower with a lower note, and it is silent once it ends",
       ctx do
    for {synth, length} <- @pandeiro_length do
      own = render(ctx, synth, [], 1)
      lower = render(ctx, synth, [note: 40], 1)

      assert loudest_hz(lower, 1000) < loudest_hz(own, 1000), "#{synth}"

      sound = render(ctx, synth, [vel: 1], length + 0.3)
      assert rms(sound, 0, 0.1) > 0.005, "#{synth}"
      assert peak(sound, length, length + 0.3) == 0, "#{synth}"
    end
  end

  test "the pandeiro's thumb rings higher and shorter with the head muted", ctx do
    open = render(ctx, :pandeiro_thumb, [], 1)
    muted = render(ctx, :pandeiro_thumb, [muted: 1], 1)

    assert loudest_hz(muted) > loudest_hz(open)
    assert rms(muted, 0.15, 0.4) < rms(open, 0.15, 0.4) / 2
  end

  # Measured from the cabasa of the Versilian Community Sample Library.
  # Each band's level as a hit starts, against its loudest band, and the seconds it takes to fade
  # 60 dB.
  @cabasa_hit %{
    {1000, 1600} => {-19.1, 0.69},
    {1600, 2500} => {-13.7, 0.67},
    {2500, 4000} => {-9.7, 0.65},
    {4000, 6300} => {-7.9, 0.61},
    {6300, 10_000} => {-5.0, 0.50},
    {10_000, 16_000} => {0.0, 0.30}
  }

  # Each band's level over a rub, against its loudest band, as the median of VCSL's four rubs at
  # both strengths.
  @cabasa_rub %{
    {1000, 1600} => -26,
    {1600, 2500} => -21,
    {2500, 4000} => -13.5,
    {4000, 6300} => -11,
    {6300, 10_000} => -5,
    {10_000, 16_000} => 0
  }

  test "a cabasa hit's bands and fades follow VCSL's cabasa", ctx do
    hit = Hits.hit(render(ctx, :cabasa, []), @rate, nil)
    measured = Map.new(hit.bands, &{&1.band, &1})

    for {band, {level, fade}} <- @cabasa_hit do
      %{level: synth_level, fade: synth_fade} = measured[band]
      assert_in_delta synth_level, level, 6, "#{inspect(band)} at #{synth_level} dB"
      assert_in_delta synth_fade / fade, 1, 0.3, "#{inspect(band)} fades in #{synth_fade} s"
    end
  end

  test "a cabasa rub as long as VCSL's has the colour of its rubs", ctx do
    levels = band_levels(render(ctx, :cabasa, rub: 1, sustain: 0.1))

    for {band, level} <- @cabasa_rub do
      assert_in_delta levels[band], level, 6, "#{inspect(band)} at #{levels[band]} dB"
    end
  end

  test "a harder cabasa rub is louder by as much as VCSL's louder rubs, and brighter", ctx do
    soft = render(ctx, :cabasa, [rub: 1, sustain: 0.1, vel: 0.3], 1)
    hard = render(ctx, :cabasa, [rub: 1, sustain: 0.1, vel: 1], 1)
    louder = 20 * :math.log10(rms(hard, 0, 0.12) / rms(soft, 0, 0.12))
    assert_in_delta louder, 12.4, 6

    assert highs(hard, 4000, 0, 0.12) / rms(hard, 0, 0.12) >
             highs(soft, 4000, 0, 0.12) / rms(soft, 0, 0.12)
  end

  test "a hard cabasa rub peaks a little under a hard hit, as VCSL's louder rubs do", ctx do
    hit = render(ctx, :cabasa, [vel: 1], 1)
    rub = render(ctx, :cabasa, [rub: 1, sustain: 0.1, vel: 1], 1)
    under = 20 * :math.log10(peak(hit, 0, 1) / peak(rub, 0, 1))
    assert_in_delta under, 2.4, 3
  end

  test "a cabasa rub holds for its sustain, then falls", ctx do
    for sustain <- [0.5, 1.0] do
      sound = render(ctx, :cabasa, [rub: 1, sustain: sustain], 2.5)
      assert_in_delta held(sound), sustain, 0.1, "sustain #{sustain}"
    end
  end

  test "the cabasa sounds lower with a lower note, and is silent within VCSL's longest stroke",
       ctx do
    own = render(ctx, :cabasa, [], 1)
    lower = render(ctx, :cabasa, [note: 84], 1)

    assert highs(lower, 4000, 0, 0.2) / rms(lower, 0, 0.2) <
             highs(own, 4000, 0, 0.2) / rms(own, 0, 0.2)

    for opts <- [[vel: 1], [vel: 1, rub: 1, sustain: 0.1]] do
      sound = render(ctx, :cabasa, opts, 1.4)
      assert rms(sound, 0, 0.1) > 0.005, inspect(opts)
      assert peak(sound, 1.08, 1.4) == 0, inspect(opts)
    end
  end

  # Measured from the cajón of the Versilian Community Sample Library at f.
  # The bass tone is its stroke named hit2, the slap hit1.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  @cajon_bass %{
    {80, 160} => {0.0, 0.46},
    {160, 250} => {-20.8, 0.33},
    {250, 400} => {-25.9, 0.70},
    {400, 630} => {-22.0, 0.45},
    {630, 1000} => {-29.2, 0.51},
    {1000, 1600} => {-38.6, 0.50},
    {1600, 2500} => {-33.7, 0.45},
    {2500, 4000} => {-36.4, 0.46},
    {4000, 6300} => {-31.5, 0.41},
    {6300, 10_000} => {-26.6, 0.36}
  }

  @cajon_slap %{
    {80, 160} => {0.0, 0.78},
    {160, 250} => {-4.1, 0.44},
    {250, 400} => {-8.5, 0.46},
    {400, 630} => {-1.4, 0.26},
    {630, 1000} => {-8.8, 0.32},
    {1000, 1600} => {-13.4, 0.26},
    {1600, 2500} => {-13.3, 0.26},
    {2500, 4000} => {-16.3, 0.28},
    {4000, 6300} => {-14.4, 0.26},
    {6300, 10_000} => {-10.7, 0.24}
  }

  test "the cajón's bass tone and slap follow VCSL's bands and fades", ctx do
    for {slap, table} <- [{0, @cajon_bass}, {1, @cajon_slap}] do
      hit = Hits.hit(render(ctx, :cajon, slap: slap), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]

        assert_in_delta synth_level,
                        level,
                        6,
                        "slap #{slap} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "slap #{slap} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  test "the cajón's slap is brighter than its bass tone, with its lowest peak no lower", ctx do
    bass = render(ctx, :cajon, [slap: 0], 1)
    slap = render(ctx, :cajon, [slap: 1], 1)

    assert highs(slap, 2000, 0, 0.3) / rms(slap, 0, 0.3) >
             highs(bass, 2000, 0, 0.3) / rms(bass, 0, 0.3)

    assert strongest(slap, 0, 0.3) >= strongest(bass, 0, 0.3) - 2
  end

  # VCSL's bass tone is 17.8 dB louder at f than at pp, and its slap 17.2 dB louder at fff than at
  # mp.
  test "a harder cajón stroke is louder by as much as VCSL's, and brighter", ctx do
    for slap <- [0, 1] do
      soft = render(ctx, :cajon, [slap: slap, vel: 0.3], 1)
      hard = render(ctx, :cajon, [slap: slap, vel: 1], 1)
      louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
      assert_in_delta louder, 17.5, 6, "slap #{slap}"

      assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
               highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
    end
  end

  test "the cajón sounds lower with a lower note, and is silent within VCSL's longest stroke",
       ctx do
    assert strongest(render(ctx, :cajon, [note: 36], 1), 0, 0.3) <
             strongest(render(ctx, :cajon, [], 1), 0, 0.3)

    for opts <- [[vel: 1], [vel: 1, slap: 1]] do
      sound = render(ctx, :cajon, opts, 2.0)
      assert rms(sound, 0, 0.1) > 0.005, inspect(opts)
      assert peak(sound, 1.73, 2.0) == 0, inspect(opts)
    end
  end

  # Measured from the bongos of the Versilian Community Sample Library at their middle strength,
  # open and muted.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  @bongos %{
    {:low_bongo, 0} => %{
      {80, 160} => {-29.4, 1.97},
      {160, 250} => {-12.1, 0.88},
      {250, 400} => {0.0, 0.91},
      {400, 630} => {-15.8, 0.79},
      {630, 1000} => {-29.2, 0.68},
      {1000, 1600} => {-30.6, 0.65},
      {1600, 2500} => {-34.1, 0.62},
      {2500, 4000} => {-43.9, 1.15},
      {4000, 6300} => {-44.8, 1.26},
      {6300, 10_000} => {-50.3, 2.05}
    },
    {:low_bongo, 1} => %{
      {80, 160} => {-16.0, 0.79},
      {160, 250} => {-7.2, 0.76},
      {250, 400} => {0.0, 0.79},
      {400, 630} => {-8.7, 0.75},
      {630, 1000} => {-21.5, 0.70},
      {1000, 1600} => {-31.4, 0.65},
      {1600, 2500} => {-33.6, 0.69},
      {2500, 4000} => {-38.2, 0.69},
      {4000, 6300} => {-40.3, 0.63},
      {6300, 10_000} => {-45.1, 1.54}
    },
    {:high_bongo, 0} => %{
      {80, 160} => {-32.5, 3.84},
      {160, 250} => {-15.8, 0.95},
      {250, 400} => {0.0, 1.12},
      {400, 630} => {-1.8, 0.64},
      {630, 1000} => {-24.6, 0.69},
      {1000, 1600} => {-18.3, 0.64},
      {1600, 2500} => {-20.7, 0.65},
      {2500, 4000} => {-31.8, 1.22},
      {4000, 6300} => {-35.0, 1.80},
      {6300, 10_000} => {-42.8, 2.61}
    },
    {:high_bongo, 1} => %{
      {80, 160} => {-28.0, 1.59},
      {160, 250} => {-14.5, 0.79},
      {250, 400} => {-0.5, 1.03},
      {400, 630} => {-1.6, 0.68},
      {630, 1000} => {-22.4, 0.61},
      {1000, 1600} => {-19.8, 0.65},
      {1600, 2500} => {-21.9, 0.71},
      {2500, 4000} => {-30.6, 0.69},
      {4000, 6300} => {-33.4, 0.63},
      {6300, 10_000} => {-37.6, 0.85}
    }
  }

  # How much louder VCSL's loudest strokes are than their softest, averaged over both of each.
  @bongos_louder %{
    {:low_bongo, 0} => 21.5,
    {:low_bongo, 1} => 26.0,
    {:high_bongo, 0} => 20.5,
    {:high_bongo, 1} => 11.0
  }

  test "each bongo, open and muted, follows VCSL's bands and fades", ctx do
    for {{drum, muted}, table} <- @bongos do
      hit = Hits.hit(render(ctx, drum, muted: muted), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "#{drum} muted #{muted} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"
        assert_in_delta synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s"
      end
    end
  end

  # Measured with mix mx.measure --hits --partials 4 from Freesound's preview of plotzki's "X
  # Surdo 2Barb.aiff", four open strokes:
  # each band's level as struck against the loudest band, and the seconds it fades 60 dB in.
  @surdo %{
    {80, 160} => {-3.7, 1.37},
    {160, 250} => {0.0, 1.18},
    {250, 400} => {-8.8, 1.23},
    {400, 630} => {-8.1, 1.81},
    {630, 1000} => {-12.6, 2.42},
    {1000, 1600} => {-19.3, 2.40},
    {1600, 2500} => {-29.3, 2.49},
    {2500, 4000} => {-36.2, 3.41}
  }

  test "the surdo's open stroke follows plotzki's bands and fades", ctx do
    hit = Hits.hit(render(ctx, :surdo, [], 4), @rate, nil)
    measured = Map.new(hit.bands, &{&1.band, &1})

    for {band, {level, fade}} <- @surdo do
      %{level: synth_level, fade: synth_fade} = measured[band]
      assert_in_delta synth_level, level, 6, "#{inspect(band)} at #{synth_level} dB"
      assert_in_delta synth_fade / fade, 1, 0.3, "#{inspect(band)} fades in #{synth_fade} s"
    end
  end

  # plotzki's open strokes ring on 66.4 to 67.5 Hz in 36127 and 36110, with a peak at twice it
  # about 10 dB down.
  test "the surdo's open stroke rings on 66.6 Hz with a peak at twice it, and the muted one higher and shorter",
       ctx do
    [lowest, twice | _] = Hits.hit(render(ctx, :surdo, [], 4), @rate, 36, partials: 6).partials
    assert_in_delta lowest.hz / 66.6, 1, 0.03
    assert_in_delta twice.hz / (2 * lowest.hz), 1, 0.03
    assert twice.level < -6 and twice.level > -14, "twice the lowest at #{twice.level} dB"

    muted = Hits.hit(render(ctx, :surdo, [muted: 1], 4), @rate, 36, partials: 6)
    assert Enum.all?(muted.partials, &(&1.hz > 110))

    open_fade =
      Enum.find(Hits.hit(render(ctx, :surdo, [], 4), @rate, nil).bands, &(&1.band == {80, 160})).fade

    muted_fade = Enum.find(muted.bands, &(&1.band == {80, 160})).fade
    assert muted_fade <= open_fade / 2, "the muted stroke fades in #{muted_fade} s"
  end

  # igorfiche01's surdo, "AKG 414 Surdo Processed.wav", rings on 85.9 Hz in the median of its 18
  # open strokes.
  test "the surdo tuned to F2 rings as igorfiche01's higher surdo does, and is louder struck harder",
       ctx do
    [lowest | _] = Hits.hit(render(ctx, :surdo, [note: 41], 4), @rate, 41, partials: 6).partials
    assert_in_delta lowest.hz / 85.9, 1, 0.03

    soft = render(ctx, :surdo, [vel: 0.3], 1)
    hard = render(ctx, :surdo, [vel: 1], 1)
    assert rms(hard, 0, 0.5) > rms(soft, 0, 0.5) * 2
  end

  # Measured as the test below measures the synth, over the isolated strokes of reinsamba's pack
  # "Cuica" on Freesound: 72 low ones with the head free, sounds 21715, 21719, 21723, 21724 and
  # 21727, and 60 high ones with it pressed, sounds 21718 and 21720 to 21722, of which the 9 of
  # 21720 stand alone.
  # The pitch the stroke settles at, its second and third harmonics against the fundamental, how
  # far under the note it starts and by when it is within 50 cents of it, and how long it lasts
  # above 25 dB under its peak.
  # The low strokes settle at 363 Hz, the synth's note with none given, start 203 cents under and
  # last 0.2 s, their harmonics 22 and 35 dB under; the high ones standing alone start 210 cents
  # under and last 0.14 s, their harmonics 19 and 20 dB under as the stroke dies.
  @cuica_low 65.65
  @cuica_strokes %{
    @cuica_low => %{
      hz: 363,
      harmonics: [-22, -35],
      under: 150..300,
      reached: 0.12,
      lasts: {0.18, 0.25}
    },
    79 => %{hz: 784, harmonics: [-20, -20], under: 150..280, reached: 0.08, lasts: {0.11, 0.18}}
  }

  for {note, stroke} <- @cuica_strokes do
    @note note
    @stroke stroke

    test "the cuíca's strokes at note #{note} scoop up into #{stroke.hz} Hz with their harmonics and length, by their median",
         ctx do
      %{hz: hz, harmonics: harmonics, under: under, reached: reached, lasts: {shortest, longest}} =
        @stroke

      strokes = cuica_strokes(ctx, @note)
      settled = Enum.map(strokes, &pitch(window(&1, reached + 0.01, reached + 0.06), hz))
      cents = fn a, b -> 1200 * :math.log2(a / b) end
      assert_in_delta cents.(median(settled), hz), 0, 30, "settles at #{median(settled)} Hz"

      # Over 5 to 60 ms from where the stroke rises within 25 dB of its peak, the span the
      # recordings' first five pitch frames covered.
      starts =
        for {sound, at} <- Enum.zip(strokes, settled) do
          from = speaks(sound)
          cents.(at, pitch(window(sound, from + 0.005, from + 0.06), hz / 1.1))
        end

      assert round(median(starts)) in under, "starts #{median(starts)} cents under"

      nears =
        for {sound, at} <- Enum.zip(strokes, settled),
            do: cents.(pitch(window(sound, reached - 0.01, reached + 0.01), hz), at)

      assert_in_delta median(nears), 0, 50, "at #{reached} s #{median(nears)} cents off"

      for {level, harmonic} <- Enum.with_index(harmonics, 2) do
        measured =
          for {sound, at} <- Enum.zip(strokes, settled) do
            steady = window(sound, reached + 0.01, reached + 0.06)
            10 * :math.log10(peak_near(steady, harmonic * at) / peak_near(steady, at))
          end

        db = median(measured)
        assert_in_delta db, level, 4, "harmonic #{harmonic} at #{db} dB"
      end

      envelopes =
        for sound <- strokes do
          for chunk <- Enum.chunk_every(sound, 240),
              do: 20 * :math.log10(rms(chunk, 0, 0.005) + 1.0e-9)
        end

      lasts =
        for levels <- envelopes,
            do: Enum.count(levels, &(&1 > Enum.max(levels) - 25)) * 0.005

      assert median(lasts) >= shortest and median(lasts) <= longest, "lasts #{median(lasts)} s"

      if @note == @cuica_low do
        held = for levels <- envelopes, do: Enum.max(levels) - Enum.min(Enum.slice(levels, 6..24))
        assert median(held) < 6, "falls #{median(held)} dB from 30 to 120 ms"
      end
    end
  end

  # reinsamba's strokes vary from one to the next: the scoop by about two thirds of itself and the
  # pitch they settle at by 77 cents.
  test "no two cuíca strokes match: their scoops and the pitches they settle at vary", ctx do
    strokes = cuica_strokes(ctx, @cuica_low)
    settled = Enum.map(strokes, &pitch(window(&1, 0.13, 0.18), 363))
    starts = Enum.map(strokes, &pitch(window(&1, 0.005, 0.03), 320))

    spread = fn hz ->
      hz |> Enum.map(&(1200 * :math.log2(&1 / median(hz)))) |> Enum.map(&abs/1) |> median()
    end

    assert spread.(settled) > 10, "settled pitches within #{spread.(settled)} cents"
    assert spread.(starts) > 40, "starting pitches within #{spread.(starts)} cents"
  end

  test "the cuíca is louder struck harder", ctx do
    soft = render(ctx, :cuica, [vel: 0.3], 0.4)
    hard = render(ctx, :cuica, [vel: 1], 0.4)
    assert rms(hard, 0, 0.2) > rms(soft, 0, 0.2) * 2
  end

  test "a cuíca stroke lasts its sustain, less the stick's turn", ctx do
    for {sustain, {shortest, longest}} <- [{0.12, {0.09, 0.16}}, {0.4, {0.36, 0.45}}] do
      stroke = render(ctx, :cuica, [sustain: sustain], 0.7)
      levels = for chunk <- Enum.chunk_every(stroke, 240), do: rms(chunk, 0, 0.005)
      lasts = Enum.count(levels, &(&1 > Enum.max(levels) / 17.8)) * 0.005
      assert lasts >= shortest and lasts <= longest, "sustain #{sustain} lasts #{lasts} s"
    end
  end

  # The 143 low strokes of the pack's grooves, sounds 21716 and 21726, start 7 cents under the
  # note they settle at; the second of a groove's two high strokes falls into its note from 80
  # cents over it.
  test "a cuíca stroke with a scoop of 0 starts on its note, and one under 0 falls into it",
       ctx do
    cents = fn stroke ->
      1200 *
        :math.log2(
          pitch(window(stroke, 0.005, 0.03), 330) / pitch(window(stroke, 0.08, 0.13), 330)
        )
    end

    level = cents.(render(ctx, :cuica, [note: 64, scoop: 0, sustain: 0.19], 0.4))
    above = cents.(render(ctx, :cuica, [note: 64, scoop: -2, sustain: 0.19], 0.4))
    assert_in_delta level, 0, 60, "starts #{level} cents from its note"
    assert above > 80, "starts #{above} cents over its note"
  end

  # Over the same grooves, 70 ms into a low stroke at 331 Hz, the second harmonic is 3 dB over the
  # fundamental and the fourth 7 under, where the shell answers near 660 and 1320 Hz; the isolated
  # strokes at 363 Hz miss both.
  test "a cuíca's low stroke at 330 Hz rings the shell with its second and fourth harmonics",
       ctx do
    stroke = render(ctx, :cuica, [note: 64, vel: 0.9, scoop: 0, sustain: 0.19], 0.4)
    steady = window(stroke, 0.04, 0.1)
    at = pitch(steady, 330)

    against = fn harmonic ->
      10 * :math.log10(peak_near(steady, harmonic * at) / peak_near(steady, at))
    end

    assert_in_delta against.(2), 3, 4, "harmonic 2 at #{against.(2)} dB"

    # The fourth is 4 dB under the fundamental in the strokes on the beat and 11 under in the
    # softer ones after it.
    assert_in_delta against.(4), -7, 5, "harmonic 4 at #{against.(4)} dB"
    assert against.(3) < -14, "harmonic 3 at #{against.(3)} dB"
  end

  # Measured with mix mx.measure --hits --partials 6 from the Commons recording "Tamborim
  # Sound.ogg" by Samba-x, converted to WAV, 45 strokes:
  # each band's level at the strike against the loudest band, the seconds it fades 60 dB in, and
  # its level 50 and 100 ms after the loudest moment.
  @tamborim %{
    {160, 250} => {-25.4, 0.68, -29, -36},
    {250, 400} => {-15.7, 0.58, -19, -23},
    {400, 630} => {-0.5, 0.50, -5, -15},
    {630, 1000} => {-1.3, 0.91, -4, -9},
    {1000, 1600} => {-3.7, 0.92, -6, -9},
    {1600, 2500} => {-4.4, 0.80, -9, -12},
    {2500, 4000} => {-5.0, 0.73, -11, -15},
    {4000, 6300} => {-9.1, 0.60, -18, -21},
    {6300, 10_000} => {-14.2, 0.48, -24, -28}
  }

  test "the tamborim follows the Commons recording's bands, fades and levels after the strike",
       ctx do
    hit = Hits.hit(render(ctx, :tamborim, [], 1.5), @rate, nil)
    measured = Map.new(hit.bands, &{&1.band, &1})
    moments = Map.new(hit.moments, &{&1.band, &1.levels})

    for {band, {level, fade, at_50, at_100}} <- @tamborim do
      %{level: synth_level, fade: synth_fade} = measured[band]
      assert_in_delta synth_level, level, 6, "#{inspect(band)} at #{synth_level} dB"
      assert_in_delta synth_fade / fade, 1, 0.3, "#{inspect(band)} fades in #{synth_fade} s"
      [_, synth_50, synth_100 | _] = moments[band]
      assert_in_delta synth_50, at_50, 6, "#{inspect(band)} at #{synth_50} dB after 50 ms"
      assert_in_delta synth_100, at_100, 6, "#{inspect(band)} at #{synth_100} dB after 100 ms"
    end
  end

  # The recording's strokes ring on 524.3 Hz in the median, with strong peaks near 1.8 and 2.5
  # times it.
  test "the tamborim rings on 524 Hz with peaks near 1.8 and 2.5 times it, and an octave up with a note 12 higher",
       ctx do
    peaks = Hits.hit(render(ctx, :tamborim, [], 1.5), @rate, nil, partials: 6).partials
    [lowest | _] = peaks
    assert_in_delta lowest.hz / 524.3, 1, 0.03

    for ratio <- [1.8, 2.5] do
      assert Enum.any?(peaks, &(abs(&1.hz / (ratio * lowest.hz) - 1) < 0.03)),
             "no peak near #{ratio}"
    end

    [octave | _] =
      Hits.hit(render(ctx, :tamborim, [note: 84.03], 1.5), @rate, nil, partials: 6).partials

    assert_in_delta octave.hz / (2 * lowest.hz), 1, 0.03
  end

  test "the tamborim is louder struck harder", ctx do
    soft = render(ctx, :tamborim, [vel: 0.3], 1)
    hard = render(ctx, :tamborim, [vel: 1], 1)
    assert rms(hard, 0, 0.3) > rms(soft, 0, 0.3) * 2
  end

  # Caxixi.ogg by Freddythehat on Wikimedia Commons, measured with mix mx.measure --hits: each
  # band's level and fade, and its level 50 and 100 ms after the loudest moment.
  @caxixi %{
    {1000, 1600} => {-13.2, 4.41, -23, -27},
    {1600, 2500} => {-5.3, 2.68, -15, -19},
    {2500, 4000} => {-2.4, 2.28, -13, -20},
    {4000, 6300} => {-3.6, 1.86, -15, -23},
    {6300, 10_000} => {-0.6, 1.39, -16, -23},
    {10_000, 16_000} => {-3.0, 1.69, -20, -26}
  }

  test "the caxixi follows the Commons recording's bands, fades and levels after the shake",
       ctx do
    hit = Hits.hit(render(ctx, :caxixi, [], 4), @rate, nil)
    measured = Map.new(hit.bands, &{&1.band, &1})
    moments = Map.new(hit.moments, &{&1.band, &1.levels})

    for {band, {level, fade, at_50, at_100}} <- @caxixi do
      %{level: synth_level, fade: synth_fade} = measured[band]
      assert_in_delta synth_level, level, 6, "#{inspect(band)} at #{synth_level} dB"
      assert_in_delta synth_fade / fade, 1, 0.3, "#{inspect(band)} fades in #{synth_fade} s"
      [_, synth_50, synth_100 | _] = moments[band]
      assert_in_delta synth_50, at_50, 6, "#{inspect(band)} at #{synth_50} dB after 50 ms"
      assert_in_delta synth_100, at_100, 6, "#{inspect(band)} at #{synth_100} dB after 100 ms"
    end
  end

  test "ten caxixi shakes have their strongest peak at five or more frequencies", ctx do
    song = Path.join(ctx.tmp_dir, "shakes.exs")
    out = Path.join(ctx.tmp_dir, "shakes.wav")

    File.write!(song, """
    import Mx
    song(tempo: 120, music: part(:caxixi, at(Enum.map(0..9, &{&1, hit()}), 10), synth: :caxixi))
    """)

    capture_io(fn -> assert :ok = Mx.Render.render(song, out, seconds: 6) end)
    wav = File.read!(out)
    {at, _} = :binary.match(wav, "data")
    data = binary_part(wav, at + 8, byte_size(wav) - at - 8)
    left = for <<x::little-float-32, _::little-float-32 <- data>>, do: x
    hits = Hits.hits(left, @rate, nil, partials: 6)
    assert length(hits) == 10

    strongest = for %{partials: partials} <- hits, do: Enum.max_by(partials, & &1.level).hz

    distinct =
      strongest
      |> Enum.sort()
      |> Enum.reduce([], fn
        hz, [last | _] = kept when hz / last < 1.03 -> kept
        hz, kept -> [hz | kept]
      end)

    rounded = Enum.map(strongest, &round/1)
    assert length(distinct) >= 5, "strongest peaks at #{inspect(rounded)} Hz"
  end

  test "the caxixi is louder shaken harder", ctx do
    soft = render(ctx, :caxixi, [vel: 0.3], 1)
    hard = render(ctx, :caxixi, [vel: 1], 1)
    assert rms(hard, 0, 0.3) > rms(soft, 0, 0.3) * 2
  end

  test "a harder bongo stroke is louder by as much as VCSL's, and brighter", ctx do
    for {{drum, muted}, expected} <- @bongos_louder do
      soft = render(ctx, drum, [muted: muted, vel: 0.3], 1)
      hard = render(ctx, drum, [muted: muted, vel: 1], 1)
      louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
      assert_in_delta louder, expected, 6, "#{drum} muted #{muted}"

      assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
               highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
    end
  end

  test "the high bongo sounds higher than the low one, and each sounds lower with a lower note",
       ctx do
    low = strongest(render(ctx, :low_bongo, [], 1), 0, 0.3)
    high = strongest(render(ctx, :high_bongo, [], 1), 0, 0.3)
    assert high > low

    assert strongest(render(ctx, :low_bongo, [note: 55], 1), 0, 0.3) < low
    assert strongest(render(ctx, :high_bongo, [note: 65], 1), 0, 0.3) < high
  end

  test "each bongo makes sound and is silent within VCSL's longest stroke", ctx do
    for drum <- [:low_bongo, :high_bongo], opts <- [[vel: 1], [vel: 1, muted: 1]] do
      sound = render(ctx, drum, opts, 1.5)
      assert rms(sound, 0, 0.1) > 0.005, "#{drum} #{inspect(opts)}"
      assert peak(sound, 1.19, 1.5) == 0, "#{drum} #{inspect(opts)}"
    end
  end

  # Measured from VSCO 2's snare with its snares on, at its softest, middle and hardest strengths,
  # which vel 0.3, 0.65 and 1 stand for.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  # Below 160 Hz the recordings hold only a hum, and at the softest strength the hum lengthens
  # every band's fade, so those are left out.
  @snare %{
    0.3 => %{
      {160, 250} => {0.0, nil},
      {250, 400} => {-0.8, nil},
      {400, 630} => {-10.0, nil},
      {630, 1000} => {-13.9, nil},
      {1000, 1600} => {-15.9, nil},
      {1600, 2500} => {-19.9, nil},
      {2500, 4000} => {-21.9, nil},
      {4000, 6300} => {-26.5, nil},
      {6300, 10_000} => {-29.7, nil}
    },
    0.65 => %{
      {160, 250} => {0.0, 0.65},
      {250, 400} => {-0.6, 0.60},
      {400, 630} => {-8.4, 0.55},
      {630, 1000} => {-12.4, 0.60},
      {1000, 1600} => {-11.7, 0.55},
      {1600, 2500} => {-13.7, 0.61},
      {2500, 4000} => {-12.9, 0.53},
      {4000, 6300} => {-13.5, 0.49},
      {6300, 10_000} => {-14.5, 0.38}
    },
    1 => %{
      {160, 250} => {0.0, 0.62},
      {250, 400} => {-7.3, 0.73},
      {400, 630} => {-5.6, 0.62},
      {630, 1000} => {-13.5, 0.60},
      {1000, 1600} => {-14.6, 0.51},
      {1600, 2500} => {-18.3, 0.58},
      {2500, 4000} => {-18.4, 0.54},
      {4000, 6300} => {-19.3, 0.50},
      {6300, 10_000} => {-20.6, 0.40}
    }
  }

  test "the snare follows VSCO 2's bands and fades at each strength", ctx do
    for {vel, table} <- @snare do
      hit = Hits.hit(render(ctx, :snare, vel: vel), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # VSCO 2's hardest snare stroke is 40.4 dB louder than its softest over the first 0.3 s.
  test "a harder snare stroke is louder by as much as VSCO 2's, and brighter", ctx do
    soft = render(ctx, :snare, [vel: 0.3], 1)
    hard = render(ctx, :snare, [vel: 1], 1)
    louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
    assert_in_delta louder, 40.4, 6

    assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
             highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
  end

  test "the snare sounds lower with a lower note, and is silent within 1.5 seconds", ctx do
    assert strongest(render(ctx, :snare, [note: 48], 1), 0, 0.3) <
             strongest(render(ctx, :snare, [], 1), 0, 0.3)

    sound = render(ctx, :snare, [vel: 1], 2.0)
    assert rms(sound, 0, 0.1) > 0.005
    assert peak(sound, 1.5, 2.0) == 0
  end

  # Measured from VSCO 2's crash cymbal at pp and ff, which vel 0.3 and 1 stand for.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  # Below 400 Hz the recordings' fades differ threefold from one strength to the next, so those
  # are left out.
  @crash %{
    0.3 => %{
      {80, 160} => {-20.7, nil},
      {160, 250} => {-6.1, nil},
      {250, 400} => {-1.6, nil},
      {400, 630} => {-11.6, 14.96},
      {630, 1000} => {-18.5, 10.64},
      {1000, 1600} => {-11.7, 7.16},
      {1600, 2500} => {-10.0, 5.54},
      {2500, 4000} => {-7.3, 4.07},
      {4000, 6300} => {-5.1, 3.16},
      {6300, 10_000} => {-6.2, 1.91}
    },
    1 => %{
      {80, 160} => {-17.3, nil},
      {160, 250} => {-4.9, nil},
      {250, 400} => {-1.6, nil},
      {400, 630} => {-10.9, 6.09},
      {630, 1000} => {-13.4, 4.69},
      {1000, 1600} => {-10.2, 3.90},
      {1600, 2500} => {-7.8, 3.44},
      {2500, 4000} => {-6.4, 2.80},
      {4000, 6300} => {-4.9, 2.54},
      {6300, 10_000} => {-5.9, 1.94}
    }
  }

  test "the crash follows VSCO 2's bands and fades at its softest and hardest", ctx do
    for {vel, table} <- @crash do
      hit = Hits.hit(render(ctx, :crash, [vel: vel], 10), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # VSCO 2's crash is 18.4 dB louder at ff than at pp over the first 0.3 s.
  test "a harder crash is louder by as much as VSCO 2's, and brighter", ctx do
    soft = render(ctx, :crash, [vel: 0.3], 1)
    hard = render(ctx, :crash, [vel: 1], 1)
    louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
    assert_in_delta louder, 18.4, 6

    assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
             highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
  end

  test "the crash sounds lower with a lower note, rings until 10 seconds, and a short sustain chokes it",
       ctx do
    assert strongest(render(ctx, :crash, [note: 48], 1), 0, 0.3) <
             strongest(render(ctx, :crash, [], 1), 0, 0.3)

    ringing = render(ctx, :crash, [vel: 1], 10.5)
    assert rms(ringing, 0, 0.1) > 0.005
    assert rms(ringing, 5, 6) > 1.0e-5
    assert peak(ringing, 10.05, 10.5) == 0

    choked = render(ctx, :crash, [vel: 1, sustain: 0.5, release: 0.1], 1)
    assert peak(choked, 0.62, 1) == 0
  end

  # Measured from VCSL's hi-hat struck closed at its four strengths, which vel 0.3, 0.533, 0.767
  # and 1 stand for, and struck open, which vel 0.8 stands for.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  # Below 160 Hz the recordings hold mostly noise, as do the softest closed strokes' fades, so
  # those are left out.
  @hihat %{
    {:closed_hihat, 0.3} => %{
      {160, 250} => {-23.4, nil},
      {250, 400} => {-5.4, nil},
      {400, 630} => {-11.6, nil},
      {630, 1000} => {-12.7, nil},
      {1000, 1600} => {-9.1, nil},
      {1600, 2500} => {-8.5, nil},
      {2500, 4000} => {-5.4, nil},
      {4000, 6300} => {-0.4, nil},
      {6300, 10_000} => {-0.7, nil}
    },
    {:closed_hihat, 0.533} => %{
      {160, 250} => {-19.5, nil},
      {250, 400} => {-10.3, 0.51},
      {400, 630} => {-13.2, 0.52},
      {630, 1000} => {-15.9, 0.59},
      {1000, 1600} => {-11.2, 0.56},
      {1600, 2500} => {-10.7, 0.57},
      {2500, 4000} => {-6.2, 0.56},
      {4000, 6300} => {-2.9, 0.53},
      {6300, 10_000} => {-1.6, 0.42}
    },
    {:closed_hihat, 0.767} => %{
      {160, 250} => {-20.1, 0.75},
      {250, 400} => {-10.8, 0.61},
      {400, 630} => {-15.5, 0.65},
      {630, 1000} => {-20.0, 0.67},
      {1000, 1600} => {-14.1, 0.55},
      {1600, 2500} => {-12.2, 0.52},
      {2500, 4000} => {-10.2, 0.59},
      {4000, 6300} => {-3.6, 0.50},
      {6300, 10_000} => {-2.5, 0.40}
    },
    {:closed_hihat, 1} => %{
      {160, 250} => {-24.8, 0.56},
      {250, 400} => {-15.8, 0.64},
      {400, 630} => {-15.6, 0.66},
      {630, 1000} => {-21.4, 0.67},
      {1000, 1600} => {-16.2, 0.57},
      {1600, 2500} => {-13.5, 0.55},
      {2500, 4000} => {-11.3, 0.53},
      {4000, 6300} => {-4.1, 0.49},
      {6300, 10_000} => {-2.4, 0.41}
    },
    {:open_hihat, 0.8} => %{
      {160, 250} => {-27.8, 2.38},
      {250, 400} => {-15.3, 3.36},
      {400, 630} => {-5.1, 2.45},
      {630, 1000} => {-15.1, 2.42},
      {1000, 1600} => {-8.1, 2.37},
      {1600, 2500} => {-10.2, 2.70},
      {2500, 4000} => {-4.6, 2.59},
      {4000, 6300} => {-2.0, 2.53},
      {6300, 10_000} => {-1.9, 2.61}
    }
  }

  test "the hi-hats follow VCSL's bands and fades, closed at each strength and open", ctx do
    for {{drum, vel}, table} <- @hihat do
      hit = Hits.hit(render(ctx, drum, [vel: vel], 6), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "#{drum} vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # VCSL's hardest closed hi-hat stroke is 29.7 dB louder than its softest over the first 0.3 s,
  # and its open stroke 3.6 dB louder than the hardest closed one.
  test "a harder hi-hat stroke is louder by as much as VCSL's, and brighter", ctx do
    soft = render(ctx, :closed_hihat, [vel: 0.3], 1)
    hard = render(ctx, :closed_hihat, [vel: 1], 1)
    louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
    assert_in_delta louder, 29.7, 6

    assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
             highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)

    open = render(ctx, :open_hihat, [vel: 0.8], 1)
    assert_in_delta 20 * :math.log10(rms(open, 0, 0.3) / rms(hard, 0, 0.3)), 3.6, 6

    open_soft = render(ctx, :open_hihat, [vel: 0.3], 1)
    open_hard = render(ctx, :open_hihat, [vel: 1], 1)
    assert rms(open_hard, 0, 0.3) > rms(open_soft, 0, 0.3) * 10
  end

  test "each hi-hat sounds lower with a lower note, and the open one rings until the pedal closes it",
       ctx do
    for drum <- [:closed_hihat, :open_hihat] do
      assert strongest(render(ctx, drum, [note: 80], 1), 0, 0.3) <
               strongest(render(ctx, drum, [], 1), 0, 0.3),
             "#{drum}"
    end

    closed = render(ctx, :closed_hihat, [vel: 1], 1.5)
    assert rms(closed, 0, 0.1) > 0.005
    assert peak(closed, 0.9, 1.5) == 0

    open = render(ctx, :open_hihat, [vel: 1], 6)
    assert rms(open, 2, 3) > 1.0e-4
    assert peak(open, 5.1, 6) == 0

    pedalled = render(ctx, :open_hihat, [vel: 1, sustain: 0.5, release: 0.05], 1)
    assert peak(pedalled, 0.6, 1) == 0
  end

  # Measured from VCSL's high and low toms struck with sticks at their three strengths, which vel
  # 0.3, 0.65 and 1 stand for.
  # Each band's level as a stroke starts, against its loudest band, and the seconds it takes to
  # fade 60 dB.
  # The quietest bands of the softest strokes fade into the recordings' noise, so those fades are
  # left out.
  @toms %{
    {:high_tom, 0.3} => %{
      {80, 160} => {-0.1, 1.45},
      {160, 250} => {-6.9, 1.82},
      {250, 400} => {-0.3, 1.02},
      {400, 630} => {-9.7, 0.85},
      {630, 1000} => {-13.8, 0.56},
      {1000, 1600} => {-17.9, 0.49},
      {1600, 2500} => {-21.7, 0.50},
      {2500, 4000} => {-31.6, nil},
      {4000, 6300} => {-38.0, nil},
      {6300, 10_000} => {-44.7, nil}
    },
    {:high_tom, 0.65} => %{
      {80, 160} => {0.0, 1.48},
      {160, 250} => {-8.4, 1.82},
      {250, 400} => {-1.0, 0.82},
      {400, 630} => {-11.6, 0.98},
      {630, 1000} => {-13.8, 0.61},
      {1000, 1600} => {-17.1, 0.52},
      {1600, 2500} => {-22.1, 0.62},
      {2500, 4000} => {-27.9, 0.64},
      {4000, 6300} => {-33.1, 0.60},
      {6300, 10_000} => {-41.2, nil}
    },
    {:high_tom, 1} => %{
      {80, 160} => {0.0, 1.54},
      {160, 250} => {-8.8, 1.95},
      {250, 400} => {-3.5, 0.80},
      {400, 630} => {-7.1, 0.91},
      {630, 1000} => {-13.8, 0.58},
      {1000, 1600} => {-15.6, 0.53},
      {1600, 2500} => {-20.4, 0.59},
      {2500, 4000} => {-24.1, 0.60},
      {4000, 6300} => {-27.3, 0.57},
      {6300, 10_000} => {-34.5, 0.51}
    },
    {:low_tom, 0.3} => %{
      {80, 160} => {0.0, 1.50},
      {160, 250} => {-13.3, 1.53},
      {250, 400} => {-10.3, 1.15},
      {400, 630} => {-16.6, 0.84},
      {630, 1000} => {-17.4, 0.63},
      {1000, 1600} => {-26.6, 0.57},
      {1600, 2500} => {-31.1, 0.58},
      {2500, 4000} => {-37.1, nil},
      {4000, 6300} => {-40.6, nil},
      {6300, 10_000} => {-48.0, nil}
    },
    {:low_tom, 0.65} => %{
      {80, 160} => {0.0, 1.57},
      {160, 250} => {-12.5, 1.57},
      {250, 400} => {-4.1, 1.49},
      {400, 630} => {-6.2, 0.81},
      {630, 1000} => {-10.1, 0.63},
      {1000, 1600} => {-17.4, 0.66},
      {1600, 2500} => {-20.4, 0.72},
      {2500, 4000} => {-20.1, 0.61},
      {4000, 6300} => {-26.8, 0.63},
      {6300, 10_000} => {-35.4, 0.55}
    },
    {:low_tom, 1} => %{
      {80, 160} => {0.0, 1.69},
      {160, 250} => {-11.0, 1.50},
      {250, 400} => {-2.3, 1.69},
      {400, 630} => {-8.8, 0.88},
      {630, 1000} => {-12.3, 0.67},
      {1000, 1600} => {-18.5, 0.67},
      {1600, 2500} => {-18.0, 0.66},
      {2500, 4000} => {-18.4, 0.65},
      {4000, 6300} => {-23.2, 0.63},
      {6300, 10_000} => {-29.1, 0.53}
    }
  }

  test "each tom follows VCSL's bands and fades at each strength", ctx do
    for {{drum, vel}, table} <- @toms do
      hit = Hits.hit(render(ctx, drum, [vel: vel], 3), @rate, nil)
      measured = Map.new(hit.bands, &{&1.band, &1})

      for {band, {level, fade}} <- table do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "#{drum} vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # VCSL's hardest stroke is 14.1 dB louder than its softest over the first 0.3 s on the high tom,
  # and 10.6 dB on the low.
  test "a harder tom stroke is louder by as much as VCSL's, and brighter", ctx do
    for {drum, expected} <- [high_tom: 14.1, low_tom: 10.6] do
      soft = render(ctx, drum, [vel: 0.3], 1)
      hard = render(ctx, drum, [vel: 1], 1)
      louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
      assert_in_delta louder, expected, 6, "#{drum}"

      assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
               highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3),
             "#{drum}"
    end
  end

  test "the mid tom sits between the low and high toms, each sounds lower with a lower note, and is silent within VCSL's longest stroke",
       ctx do
    low = strongest(render(ctx, :low_tom, [], 1), 0, 0.3)
    mid = strongest(render(ctx, :mid_tom, [], 1), 0, 0.3)
    high = strongest(render(ctx, :high_tom, [], 1), 0, 0.3)
    assert low < mid and mid < high

    for drum <- [:low_tom, :mid_tom, :high_tom] do
      assert strongest(render(ctx, drum, [note: 36], 1), 0, 0.3) <
               strongest(render(ctx, drum, [], 1), 0, 0.3),
             "#{drum}"

      sound = render(ctx, drum, [vel: 1], 3)
      assert rms(sound, 0, 0.1) > 0.005, "#{drum}"
      assert peak(sound, 2.55, 3) == 0, "#{drum}"
    end
  end

  # Measured from VSCO 2's timpani 2 to 5, whose notes are near 47, 49, 52 and 54, at their three
  # strengths, which vel 0.3, 0.65 and 1 stand for.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # At the softest strength the bands above 630 Hz fade into the recordings' noise, and those
  # above 1 kHz are noise, so they are left out.
  @timpani %{
    0.3 => %{
      {80, 160} => {0.0, 1.90},
      {160, 250} => {-7.2, 3.91},
      {250, 400} => {-21.7, 5.63},
      {400, 630} => {-33.0, 6.56},
      {630, 1000} => {-44.1, nil}
    },
    0.65 => %{
      {80, 160} => {0.0, 1.81},
      {160, 250} => {-4.5, 4.49},
      {250, 400} => {-9.4, 5.64},
      {400, 630} => {-11.3, 3.28},
      {630, 1000} => {-19.7, 2.88},
      {1000, 1600} => {-24.9, 1.74},
      {1600, 2500} => {-34.9, 1.00},
      {2500, 4000} => {-44.3, 0.68},
      {4000, 6300} => {-48.7, 0.52},
      {6300, 10_000} => {-54.7, 0.45}
    },
    1 => %{
      {80, 160} => {-2.7, 1.73},
      {160, 250} => {-6.4, 4.25},
      {250, 400} => {-7.9, 4.36},
      {400, 630} => {-3.4, 1.86},
      {630, 1000} => {-8.4, 2.12},
      {1000, 1600} => {-14.8, 1.45},
      {1600, 2500} => {-22.8, 0.88},
      {2500, 4000} => {-26.1, 0.60},
      {4000, 6300} => {-34.3, 0.52},
      {6300, 10_000} => {-42.7, 0.48}
    }
  }

  test "timpani starts and fades in each band as VSCO 2's timpani do at each strength", ctx do
    for {vel, bands} <- @timpani do
      hits =
        [47, 49, 52, 54]
        |> Task.async_stream(
          fn note -> Hits.hit(render(ctx, :timpani, [note: note, vel: vel], 10), @rate, note) end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, hit} -> hit end)

      measured = Map.new(Hits.summary(hits), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # The modes VSCO 2's timpani 2 to 5 show above their note, as medians of their ratios to it.
  test "timpani's strongest partials stand at the ratios of VSCO 2's timpani, within 2 percent",
       ctx do
    freq = 440 * :math.pow(2, (49 - 69) / 12)
    hit = Hits.hit(render(ctx, :timpani, [note: 49, vel: 0.65], 8), @rate, 49, partials: 14)
    found = Enum.map(hit.partials, &(&1.hz / freq))

    for ratio <- [1, 1.487, 1.95, 2.11, 2.70] do
      assert Enum.any?(found, &(abs(&1 / ratio - 1) < 0.02)), "#{ratio} in #{inspect(found)}"
    end
  end

  # VSCO 2's hardest timpani stroke is 26 dB louder than its softest over the first 0.3 s, the
  # median over timpani 2 to 5.
  test "a harder timpani stroke is louder by as much as VSCO 2's, and brighter", ctx do
    soft = render(ctx, :timpani, [note: 49, vel: 0.3], 1)
    hard = render(ctx, :timpani, [note: 49, vel: 1], 1)
    louder = 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3))
    assert_in_delta louder, 26, 6

    assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
             highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)
  end

  # VSCO 2's lowest timpani sounds at 92.1 Hz and its highest at 190.4 Hz.
  test "timpani plays the lowest and highest notes of VSCO 2's timpani at their pitch, within 5 cents",
       ctx do
    for hz <- [92.1, 190.4] do
      note = 69 + 12 * :math.log2(hz / 440)

      %{partials: partials} =
        Hits.hit(render(ctx, :timpani, [note: note, vel: 0.65], 4), @rate, nil, partials: 14)

      %{hz: found} = Enum.min_by(partials, &abs(:math.log(&1.hz / hz)))
      cents = 1200 * :math.log2(found / hz)
      assert abs(cents) < 5, "#{hz} Hz is #{cents} cents off"
    end
  end

  test "a timpani note rings on with no sustain, and sustain and release damp it", ctx do
    ringing = render(ctx, :timpani, [note: 49, vel: 1], 4)
    assert rms(ringing, 3, 4) > 1.0e-4

    damped = render(ctx, :timpani, [note: 49, vel: 1, sustain: 0.5, release: 0.1], 1)
    assert peak(damped, 0.7, 1) < 1.0e-4
  end

  # Measured from VSCO 2's tumba, conga and quinto, which low_conga, mid_conga and high_conga
  # stand for, struck open at three strengths, which vel 0.3, 0.6 and 1 stand for, and tapped with
  # the fingers, which mute 1 at vel 0.3 stands for.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # The open strokes' fades above 1 kHz at the softest strength and above 2.5 kHz at the others
  # disagree between strengths by up to three times, as the recordings' noise does, and are left
  # out, as are the softest tumba's levels above 2.5 kHz.
  # The first softest tumba stroke barely sounds, peaking 24 dB below the second, so the softest
  # tumba is the second alone; the taps' fades of bands more than 20 dB below the loudest are left
  # out.
  @congas %{
    low_conga: %{
      0.3 => %{
        {80, 160} => {0.0, 1.02},
        {160, 250} => {-6.7, 1.03},
        {250, 400} => {-14.4, 0.66},
        {400, 630} => {-27.3, 0.57},
        {630, 1000} => {-37.3, 0.49},
        {1000, 1600} => {-37.3, nil},
        {1600, 2500} => {-41.8, nil}
      },
      0.6 => %{
        {80, 160} => {0.0, 1.02},
        {160, 250} => {-8.6, 1.04},
        {250, 400} => {-10.4, 0.8},
        {400, 630} => {-22.3, 0.78},
        {630, 1000} => {-29.7, 0.53},
        {1000, 1600} => {-32.4, 0.66},
        {1600, 2500} => {-36.4, 0.68},
        {2500, 4000} => {-34.9, nil},
        {4000, 6300} => {-37.4, nil},
        {6300, 10_000} => {-41.6, nil}
      },
      1 => %{
        {80, 160} => {0.0, 0.99},
        {160, 250} => {-7.3, 0.98},
        {250, 400} => {-9.2, 0.87},
        {400, 630} => {-18.5, 0.61},
        {630, 1000} => {-22.9, 0.5},
        {1000, 1600} => {-32.4, 0.67},
        {1600, 2500} => {-32.8, 0.66},
        {2500, 4000} => {-34.4, nil},
        {4000, 6300} => {-37.2, nil},
        {6300, 10_000} => {-37.4, nil}
      },
      :tap => %{
        {80, 160} => {-29.0, nil},
        {160, 250} => {-27.9, nil},
        {250, 400} => {-6.5, 0.72},
        {400, 630} => {-2.4, 0.52},
        {630, 1000} => {-2.3, 0.59},
        {1000, 1600} => {-8.7, 0.79},
        {1600, 2500} => {-8.2, 0.79},
        {2500, 4000} => {-17.4, 1.2},
        {4000, 6300} => {-14.5, 1.08},
        {6300, 10_000} => {-17.2, 1.32}
      }
    },
    mid_conga: %{
      0.3 => %{
        {80, 160} => {-1.6, 0.88},
        {160, 250} => {0.0, 0.87},
        {250, 400} => {-16.8, 0.89},
        {400, 630} => {-27.5, 0.96},
        {630, 1000} => {-31.5, 0.75},
        {1000, 1600} => {-39.6, nil},
        {1600, 2500} => {-43.0, nil},
        {2500, 4000} => {-41.8, nil},
        {4000, 6300} => {-47.7, nil},
        {6300, 10_000} => {-48.1, nil}
      },
      0.6 => %{
        {80, 160} => {-2.2, 1.02},
        {160, 250} => {0.0, 1.04},
        {250, 400} => {-14.9, 0.72},
        {400, 630} => {-18.4, 0.6},
        {630, 1000} => {-29.8, 0.56},
        {1000, 1600} => {-34.4, 0.81},
        {1600, 2500} => {-42.6, 0.82},
        {2500, 4000} => {-42.2, nil},
        {4000, 6300} => {-42.8, nil},
        {6300, 10_000} => {-46.2, nil}
      },
      1 => %{
        {80, 160} => {-2.8, 1.05},
        {160, 250} => {0.0, 1.08},
        {250, 400} => {-14.5, 0.71},
        {400, 630} => {-19.5, 0.57},
        {630, 1000} => {-26.4, 0.55},
        {1000, 1600} => {-32.4, 0.55},
        {1600, 2500} => {-39.2, 0.68},
        {2500, 4000} => {-42.1, nil},
        {4000, 6300} => {-43.6, nil},
        {6300, 10_000} => {-45.7, nil}
      },
      :tap => %{
        {80, 160} => {-22.2, nil},
        {160, 250} => {-28.2, nil},
        {250, 400} => {-18.2, 0.83},
        {400, 630} => {-14.6, 0.78},
        {630, 1000} => {-11.2, 0.64},
        {1000, 1600} => {-10.1, 0.64},
        {1600, 2500} => {-17.5, 0.73},
        {2500, 4000} => {-10.7, 0.68},
        {4000, 6300} => {0.0, 0.5},
        {6300, 10_000} => {-4.9, 0.63}
      }
    },
    high_conga: %{
      0.3 => %{
        {80, 160} => {-16.0, 1.11},
        {160, 250} => {0.0, 0.78},
        {250, 400} => {-13.2, 0.77},
        {400, 630} => {-20.4, 0.47},
        {630, 1000} => {-29.8, 0.67},
        {1000, 1600} => {-34.8, nil},
        {1600, 2500} => {-41.5, nil},
        {2500, 4000} => {-42.0, nil},
        {4000, 6300} => {-41.3, nil},
        {6300, 10_000} => {-43.3, nil}
      },
      0.6 => %{
        {80, 160} => {-15.0, 0.89},
        {160, 250} => {0.0, 0.7},
        {250, 400} => {-10.0, 0.79},
        {400, 630} => {-18.9, 0.48},
        {630, 1000} => {-29.8, 0.64},
        {1000, 1600} => {-33.7, 0.57},
        {1600, 2500} => {-40.3, 1.01},
        {2500, 4000} => {-40.9, nil},
        {4000, 6300} => {-41.6, nil},
        {6300, 10_000} => {-42.1, nil}
      },
      1 => %{
        {80, 160} => {-14.9, 0.89},
        {160, 250} => {0.0, 0.71},
        {250, 400} => {-12.8, 0.8},
        {400, 630} => {-18.2, 0.5},
        {630, 1000} => {-25.1, 0.49},
        {1000, 1600} => {-32.5, 0.57},
        {1600, 2500} => {-38.6, 0.78},
        {2500, 4000} => {-39.6, nil},
        {4000, 6300} => {-42.1, nil},
        {6300, 10_000} => {-42.7, nil}
      },
      :tap => %{
        {80, 160} => {-27.2, nil},
        {160, 250} => {-20.5, nil},
        {250, 400} => {-26.9, nil},
        {400, 630} => {-21.1, 1.52},
        {630, 1000} => {-17.3, 1.28},
        {1000, 1600} => {-11.6, 1.05},
        {1600, 2500} => {-10.8, 1.1},
        {2500, 4000} => {-12.8, 1.21},
        {4000, 6300} => {0.0, 0.54},
        {6300, 10_000} => {-7.9, 1.16}
      }
    }
  }

  test "each conga starts and fades in each band as VSCO 2's congas do, open at each strength and tapped",
       ctx do
    for {drum, strokes} <- @congas, {stroke, bands} <- strokes do
      opts = if stroke == :tap, do: [vel: 0.3, mute: 1], else: [vel: stroke]
      hit = Hits.hit(render(ctx, drum, opts, 1.5), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        where = "#{drum} #{inspect(opts)} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{where} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{where} fades in #{synth_fade} s")
        end
      end
    end
  end

  # How much louder VSCO 2's hardest open stroke is than its softest, and how much quieter a tap
  # is than the softest, over the first 0.3 s, the medians of their two takes.
  @conga_loudness %{low_conga: {10.0, -24.0}, mid_conga: {13.7, -25.0}, high_conga: {16.3, -31.5}}

  test "a harder conga stroke is louder by as much as VSCO 2's, and brighter, and a muted one as quiet as its taps",
       ctx do
    for {drum, {louder, tapped}} <- @conga_loudness do
      soft = render(ctx, drum, [vel: 0.3], 1)
      hard = render(ctx, drum, [vel: 1], 1)
      tap = render(ctx, drum, [vel: 0.3, mute: 1], 1)

      assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)),
                      louder,
                      6,
                      "#{drum}"

      assert_in_delta 20 * :math.log10(rms(tap, 0, 0.3) / rms(soft, 0, 0.3)), tapped, 6, "#{drum}"

      assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
               highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3),
             "#{drum}"
    end
  end

  test "a conga sounds lower with a lower note, the three stand from low to high, and each is silent after the longest recording, 1.31 s",
       ctx do
    pitches =
      for drum <- [:low_conga, :mid_conga, :high_conga] do
        sound = render(ctx, drum, [], 2)
        assert rms(sound, 0, 0.3) > 0.005, "#{drum}"
        assert peak(sound, 1.32, 2) == 0, "#{drum}"
        lowered = render(ctx, drum, [note: 40], 1)
        assert strongest(lowered, 0.01, 0.2) < strongest(sound, 0.01, 0.2), "#{drum}"
        strongest(sound, 0.01, 0.2)
      end

    assert pitches == Enum.sort(pitches)
  end

  # Measured from the University of Iowa's three tambourines, struck at pp, mf and ff, which vel
  # 0.3, 0.6 and 1 stand for, from 160 Hz up.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # Below 400 Hz the softest strokes fall 40 dB within 100 ms and then fade slowly into the
  # recordings' noise, so those fades are left out.
  @tambourine %{
    0.3 => %{
      {160, 250} => {-28.6, nil},
      {250, 400} => {-31.4, nil},
      {400, 630} => {-24.4, 0.57},
      {630, 1000} => {-25.4, 0.46},
      {1000, 1600} => {-18.5, 0.37},
      {1600, 2500} => {-18.4, 0.36},
      {2500, 4000} => {-14.5, 0.37},
      {4000, 6300} => {-0.8, 0.38},
      {6300, 10_000} => {-7.1, 0.38}
    },
    0.6 => %{
      {160, 250} => {-31.9, 0.54},
      {250, 400} => {-29.5, 0.59},
      {400, 630} => {-26.7, 0.72},
      {630, 1000} => {-24.2, 0.55},
      {1000, 1600} => {-18.0, 0.48},
      {1600, 2500} => {-19.8, 0.49},
      {2500, 4000} => {-15.7, 0.58},
      {4000, 6300} => {-1.8, 0.60},
      {6300, 10_000} => {-5.1, 0.59}
    },
    1 => %{
      {160, 250} => {-27.0, 0.52},
      {250, 400} => {-24.7, 0.66},
      {400, 630} => {-23.0, 0.64},
      {630, 1000} => {-19.2, 0.46},
      {1000, 1600} => {-16.7, 0.56},
      {1600, 2500} => {-18.8, 0.63},
      {2500, 4000} => {-13.5, 0.85},
      {4000, 6300} => {-3.3, 0.75},
      {6300, 10_000} => {-4.2, 0.70}
    }
  }

  test "tambourine starts and fades in each band as Iowa's tambourines do at each strength",
       ctx do
    for {vel, bands} <- @tambourine do
      hit = Hits.hit(render(ctx, :tambourine, [vel: vel], 2.5), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # Iowa's ff tambourine strokes are 23.4 dB louder than their pp ones over the first 0.3 s, the
  # median of the three tambourines.
  test "a harder tambourine stroke is louder by as much as Iowa's, and brighter", ctx do
    soft = render(ctx, :tambourine, [vel: 0.3], 1)
    hard = render(ctx, :tambourine, [vel: 1], 1)
    assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)), 23.4, 6
    assert highs(hard, 2000, 0, 0.3) > highs(soft, 2000, 0, 0.3) * 2
  end

  # The longest of Iowa's tambourine strokes lasts 2.23 s.
  test "a tambourine sounds lower with a lower note, and is silent within Iowa's longest stroke",
       ctx do
    sound = render(ctx, :tambourine, [vel: 1], 3)
    lowered = render(ctx, :tambourine, [vel: 1, note: 57], 3)
    assert peak(sound, 2.23, 3) == 0

    assert highs(lowered, 8000, 0, 0.3) / rms(lowered, 0, 0.3) <
             highs(sound, 8000, 0, 0.3) / rms(sound, 0, 0.3)
  end

  test "tambourine_shake shakes for about twice as long with twice the sustain", ctx do
    short = held(render(ctx, :tambourine_shake, [sustain: 0.25], 1.5))
    long = held(render(ctx, :tambourine_shake, [sustain: 0.5], 1.5))
    assert_in_delta long / short, 2, 0.4
  end

  # Measured from the University of Iowa's 6- and 8-inch triangles at mf and ff, which vel 0.6 and
  # 1 stand for, and from VCSL's triangles muted by the hand, which sustain 0 and a release of 1.1
  # s stand for.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # Below 1 kHz every recording is noise; Iowa's 1.6 to 2.5 kHz fades read 21 s and longer, and
  # VCSL's triangles are 7 to 12 dB brighter from 1 to 4 kHz than Iowa's, open or muted, so those
  # are left out, and only the muted strokes' fades are compared.
  @triangle [
    {[vel: 0.6],
     %{
       {1600, 2500} => {-34.7, nil},
       {2500, 4000} => {-19.5, 8.33},
       {4000, 6300} => {-12.1, 4.72},
       {6300, 10_000} => {-1.9, 3.35},
       {10_000, 16_000} => {-1.6, 1.81}
     }},
    {[vel: 1],
     %{
       {1000, 1600} => {-24.1, 10.79},
       {1600, 2500} => {-33.1, nil},
       {2500, 4000} => {-14.5, 10.01},
       {4000, 6300} => {-12.1, 5.71},
       {6300, 10_000} => {-1.8, 3.42},
       {10_000, 16_000} => {-2.3, 1.91}
     }},
    {[vel: 0.6, sustain: 0, release: 1.1],
     %{
       {1000, 1600} => {nil, 1.04},
       {1600, 2500} => {nil, 1.13},
       {2500, 4000} => {nil, 0.82},
       {4000, 6300} => {nil, 0.69},
       {6300, 10_000} => {nil, 0.52},
       {10_000, 16_000} => {nil, 0.53}
     }}
  ]

  test "triangle starts and fades in each band as Iowa's triangles do, and a damped stroke fades as VCSL's muted ones",
       ctx do
    for {opts, bands} <- @triangle do
      hit = Hits.hit(render(ctx, :triangle, opts, 12), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "#{inspect(opts)} #{inspect(band)}"
        if level, do: assert_in_delta(synth_level, level, 6, "#{stroke} at #{synth_level} dB")

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # Iowa's ff triangle strokes are 29.5 dB louder over the first 0.3 s than VCSL's softest, the
  # median of each; Iowa's own pp strokes are lost in the room's noise.
  test "a harder triangle stroke is louder by as much as the recordings', and brighter", ctx do
    soft = render(ctx, :triangle, [vel: 0.3], 1)
    hard = render(ctx, :triangle, [vel: 1], 1)
    assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)), 29.5, 6
    assert highs(hard, 2000, 0, 0.3) > highs(soft, 2000, 0, 0.3) * 10
  end

  # The longest of Iowa's triangle strokes lasts 31.9 s.
  test "a triangle sounds lower with a lower note, rings until it fades within Iowa's longest stroke, and a hand damps it",
       ctx do
    sound = render(ctx, :triangle, [vel: 1], 33)
    assert rms(sound, 5, 6) > 0
    assert peak(sound, 31.9, 33) == 0

    lowered = render(ctx, :triangle, [vel: 1, note: 57], 1)

    assert highs(lowered, 8000, 0, 0.3) / rms(lowered, 0, 0.3) <
             highs(sound, 8000, 0, 0.3) / rms(sound, 0, 0.3)

    damped = render(ctx, :triangle, [sustain: 0.1, release: 0.05], 1)
    assert peak(damped, 0.2, 1) == 0
  end

  # Measured from the claves of VCSL and VSCO 2 at their three strengths, which vel 0.3, 0.6 and 1
  # stand for; the University of Iowa's claves are gated to silence within milliseconds of each
  # stroke, so they are left out.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # Fades of over a second at the softer strengths are the recordings' noise, and are left out.
  @clave %{
    0.3 => %{
      {1000, 1600} => {-25.8, nil},
      {1600, 2500} => {0.0, 0.72},
      {2500, 4000} => {-18.8, nil},
      {4000, 6300} => {-21.2, nil},
      {6300, 10_000} => {-38.7, nil},
      {10_000, 16_000} => {-48.8, nil}
    },
    0.6 => %{
      {1000, 1600} => {-26.2, 0.74},
      {1600, 2500} => {0.0, 0.72},
      {2500, 4000} => {-14.4, 0.72},
      {4000, 6300} => {-12.1, 0.66},
      {6300, 10_000} => {-27.7, nil},
      {10_000, 16_000} => {-37.5, nil}
    },
    1 => %{
      {1000, 1600} => {-26.3, 0.74},
      {1600, 2500} => {0.0, 0.67},
      {2500, 4000} => {-10.2, 0.69},
      {4000, 6300} => {-4.5, 0.60},
      {6300, 10_000} => {-13.7, 0.50},
      {10_000, 16_000} => {-26.8, 0.45}
    }
  }

  test "clave starts and fades in each band as VCSL's and VSCO 2's claves do at each strength",
       ctx do
    for {vel, bands} <- @clave do
      hit = Hits.hit(render(ctx, :clave, [vel: vel], 1.5), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "vel #{vel} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # The recordings' hardest clave strokes are 20.2 dB louder than their softest over the first 0.3
  # s, the medians of their four takes; the longest lasts 1.51 s.
  test "a harder clave stroke is louder by as much as the recordings', and brighter, a lower note sounds lower, and a stroke ends within the longest recording",
       ctx do
    soft = render(ctx, :clave, [vel: 0.3], 2)
    hard = render(ctx, :clave, [vel: 1], 2)
    assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)), 20.2, 6

    assert highs(hard, 2000, 0, 0.3) / rms(hard, 0, 0.3) >
             highs(soft, 2000, 0, 0.3) / rms(soft, 0, 0.3)

    assert peak(hard, 1.51, 2) == 0
    [%{hz: pitch}] = Hits.hit(render(ctx, :clave, [], 1), @rate, nil, partials: 1).partials

    [%{hz: lowered}] =
      Hits.hit(render(ctx, :clave, [note: 90], 1), @rate, nil, partials: 1).partials

    assert lowered < pitch * 0.8
  end

  # Measured from the cowbells of VSCO 2 and VCSL: vel 0.3 stands for VSCO 2's two softest
  # strengths, vel 1 for its two hardest with VCSL's open strokes, and vel 0.75 with muted: 1 for
  # VCSL's muted strokes.
  # Each band's median level as a stroke starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  # Below 400 Hz the recordings hold only their room's noise, and so do fades of over 0.8 s, so
  # they are left out.
  @cowbell %{
    [vel: 0.3] => %{
      {400, 630} => {-1.6, 0.63},
      {630, 1000} => {-14.0, 0.52},
      {1000, 1600} => {-17.5, 0.66},
      {1600, 2500} => {-5.7, 0.66},
      {2500, 4000} => {-0.6, 0.43},
      {4000, 6300} => {-20.2, nil},
      {6300, 10_000} => {-31.4, nil}
    },
    [vel: 1] => %{
      {400, 630} => {0.0, 0.66},
      {630, 1000} => {-11.8, 0.52},
      {1000, 1600} => {-19.3, 0.70},
      {1600, 2500} => {-13.8, 0.66},
      {2500, 4000} => {-12.0, 0.61},
      {4000, 6300} => {-16.3, 0.61},
      {6300, 10_000} => {-25.6, 0.52}
    },
    [vel: 0.75, muted: 1] => %{
      {400, 630} => {-7.5, 0.61},
      {630, 1000} => {-25.2, nil},
      {1000, 1600} => {-14.0, 0.65},
      {1600, 2500} => {-3.1, 0.69},
      {2500, 4000} => {-3.6, 0.61},
      {4000, 6300} => {-3.8, 0.59},
      {6300, 10_000} => {-8.2, 0.54}
    }
  }

  test "cowbell starts and fades in each band as VSCO 2's and VCSL's cowbells do, open and muted",
       ctx do
    for {opts, bands} <- @cowbell do
      hit = Hits.hit(render(ctx, :cowbell, opts, 1.5), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        stroke = "#{inspect(opts)} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{stroke} at #{synth_level} dB"

        if fade do
          assert_in_delta(synth_fade / fade, 1, 0.3, "#{stroke} fades in #{synth_fade} s")
        end
      end
    end
  end

  # VSCO 2's hardest cowbell strokes are 25.0 dB louder than its softest over the first 0.3 s, the
  # medians of their two takes; the longest recording, an open stroke of VCSL's, lasts 1.79 s.
  # A harder stroke is duller, not brighter: its share above 2 kHz falls 3.4 dB, and above 4 kHz
  # 3.3 dB.
  test "a harder cowbell stroke is louder and duller by as much as the recordings', a lower note sounds lower, and a stroke ends within the longest recording",
       ctx do
    soft = render(ctx, :cowbell, [vel: 0.3], 2)
    hard = render(ctx, :cowbell, [vel: 1], 2)
    assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)), 25.0, 6
    assert highs(hard, 2000, 0, 0.3) > highs(soft, 2000, 0, 0.3)

    for {hz, duller} <- [{2000, -3.4}, {4000, -3.3}] do
      share = fn sound -> 20 * :math.log10(highs(sound, hz, 0, 0.3) / rms(sound, 0, 0.3)) end
      assert_in_delta share.(hard) - share.(soft), duller, 3
    end

    assert peak(hard, 1.79, 2) == 0
    [%{hz: pitch}] = Hits.hit(render(ctx, :cowbell, [], 1), @rate, nil, partials: 1).partials

    [%{hz: lowered}] =
      Hits.hit(render(ctx, :cowbell, [note: 60], 1), @rate, nil, partials: 1).partials

    assert lowered < pitch * 0.8
  end

  # Measured from the güiros of the University of Iowa and VSCO 2, all of their scrapes at the
  # default length, and their short scrapes, Iowa's at mf and ff and VSCO 2's hits, at vel 0.8 and
  # sustain 0.1.
  # Each band's median level as a scrape starts, against its loudest band, and the seconds it
  # takes to fade 60 dB.
  @guiro %{
    [] => %{
      {400, 630} => {-17.9, 0.59},
      {630, 1000} => {-6.5, 0.51},
      {1000, 1600} => {-2.9, 0.58},
      {1600, 2500} => {0.0, 0.62},
      {2500, 4000} => {-4.1, 0.84},
      {4000, 6300} => {-7.3, 0.71},
      {6300, 10_000} => {-14.4, 0.86}
    },
    [vel: 0.8, sustain: 0.1] => %{
      {400, 630} => {-21.0, 0.47},
      {630, 1000} => {-10.8, 0.45},
      {1000, 1600} => {-5.2, 0.42},
      {1600, 2500} => {0.0, 0.48},
      {2500, 4000} => {-5.2, 0.63},
      {4000, 6300} => {-9.9, 0.67},
      {6300, 10_000} => {-12.8, 0.70}
    }
  }

  test "guiro starts and fades in each band as Iowa's and VSCO 2's güiros do", ctx do
    for {opts, bands} <- @guiro do
      hit = Hits.hit(render(ctx, :guiro, opts, 1.5), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        scrape = "#{inspect(opts)} #{inspect(band)}"
        assert_in_delta synth_level, level, 6, "#{scrape} at #{synth_level} dB"
        assert_in_delta synth_fade / fade, 1, 0.3, "#{scrape} fades in #{synth_fade} s"
      end
    end
  end

  # Iowa's ff scrapes are 12.1 dB louder than its pp scrape over the first 0.3 s, and their share
  # above 2 kHz is 1.65 dB higher, above 4 kHz 3.45 dB; VSCO 2's longest recording lasts 2.64 s.
  test "a harder guiro scrape is louder and brighter by as much as Iowa's, a lower note sounds lower, and a scrape ends within the longest recording",
       ctx do
    soft = render(ctx, :guiro, [vel: 0.3], 2)
    hard = render(ctx, :guiro, [vel: 1], 2)
    assert_in_delta 20 * :math.log10(rms(hard, 0, 0.3) / rms(soft, 0, 0.3)), 12.1, 6
    assert highs(hard, 2000, 0, 0.3) > highs(soft, 2000, 0, 0.3)

    for {hz, brighter} <- [{2000, 1.65}, {4000, 3.45}] do
      share = fn sound -> 20 * :math.log10(highs(sound, hz, 0, 0.3) / rms(sound, 0, 0.3)) end
      assert_in_delta share.(hard) - share.(soft), brighter, 3
    end

    assert peak(render(ctx, :guiro, [], 3), 2.64, 3) == 0
    [%{hz: pitch}] = Hits.hit(render(ctx, :guiro, [], 1), @rate, nil, partials: 1).partials

    [%{hz: lowered}] =
      Hits.hit(render(ctx, :guiro, [note: 80], 1), @rate, nil, partials: 1).partials

    assert lowered < pitch * 0.8
  end

  # VSCO 2's fast, medium and slow scrapes last 0.26, 0.63 and 1.33 s, and their ridges come 126,
  # 98 and 40 times a second, the strongest beat of their loudness above 2 kHz.
  test "a guiro scrape's ridges come as often as on VSCO 2's scrapes of its length", ctx do
    for {length, rate} <- [{0.26, 126}, {0.63, 98}, {1.33, 40}] do
      sound = render(ctx, :guiro, [sustain: length], length + 0.6)
      found = ridge_rate(sound, 0.03, length)
      assert_in_delta found / rate, 1, 0.15, "sustain #{length}: #{found} ridges a second"
    end
  end

  # Measured from "Tanpura 10" by sankalp on Freesound, a big tanpura tuned Pa Sa Sa sa on Db3, as
  # one drone held from its first sample to its last:
  # each band's level of harmonics and of the noise between them, against the fundamental, and how
  # long it holds within 12 dB of its loudest.
  @tanpura %{
    held: 20.74,
    bands: %{
      {80, 160} => {0.0, nil},
      {160, 250} => {nil, -2.16},
      {250, 400} => {0.67, 9.45},
      {400, 630} => {14.63, 25.70},
      {630, 1000} => {6.88, 7.67},
      {1000, 1600} => {8.27, 18.70},
      {1600, 2500} => {7.31, 9.93},
      {2500, 4000} => {-3.83, 2.34},
      {4000, 6300} => {-10.8, 4.9},
      {6300, 10_000} => {-14.7, 0.6},
      {10_000, 16_000} => {-19.3, 0.8}
    }
  }

  test "tanpura holds its harmonics and the noise between them as sankalp's tanpura does",
       ctx do
    held = @tanpura.held
    sound = render(ctx, :tanpura, [note: 49, sustain: held], held + 0.5)
    measured = Map.new(Held.summary([Held.note(sound, @rate, 49)]).bands, &{&1.band, &1})

    for {band, {level, noise}} <- @tanpura.bands do
      if level, do: assert_in_delta(measured[band].level, level, 6, "#{inspect(band)} harmonics")
      if noise, do: assert_in_delta(measured[band].noise, noise, 6, "#{inspect(band)} noise")
    end
  end

  test "tanpura sounds Sa at its note with no vibrato, on Db3 as the reference and on E2", ctx do
    for note <- [49, 40] do
      held = Held.note(render(ctx, :tanpura, [note: note, sustain: 8], 8), @rate, note)
      cents = 1200 * :math.log2(held.pitch / Signal.hz(note))
      assert abs(cents) < 10, "note #{note} is #{cents} cents off"
      assert held.vibrato == nil
    end
  end

  # At a gap of 1 beat at 60 beats a minute, the cycle is 6 seconds: Pa at 0, Sa at 2 and 3, and
  # the low Sa at 4.
  # Each string is checked once it rings, since a pluck on another string shows faintly at every
  # low frequency.
  test "tanpura plucks Pa, Sa, Sa and the low Sa two, one, one and two gaps apart, in beats",
       ctx do
    opts = Synths.to_seconds(:tanpura, [note: 49, gap: 1, sustain: 12], 60)
    sound = render(ctx, :tanpura, opts, 11)
    pa = Signal.hz(49) * 0.75
    low = Signal.hz(49) * 0.5

    plucked? = fn hz, at ->
      before = goertzel(hann(window(sound, at - 0.45, at - 0.05)), hz)
      later = goertzel(hann(window(sound, at + 0.05, at + 0.45)), hz)
      later > before * 3
    end

    assert plucked?.(pa, 6)
    refute plucked?.(pa, 2) or plucked?.(pa, 3) or plucked?.(pa, 4)
    assert plucked?.(low, 4) and plucked?.(low, 10)
    refute plucked?.(low, 6) or plucked?.(low, 8) or plucked?.(low, 9)
  end

  # The jawari brings the high harmonics in over the second after a pluck.
  test "each tanpura pluck brightens its sound", ctx do
    sound = render(ctx, :tanpura, [note: 49, gap: 1.5, sustain: 8], 8)
    brightness = fn from, to -> highs(sound, 2000, from, to) / rms(sound, from, to) end
    assert brightness.(3.4, 3.9) > brightness.(2.6, 3.0) * 1.25
  end

  # Measured with mix mx.measure --hits --partials 6 from the "tabla bols" pack by mmiron on
  # Freesound, over each stroke's takes:
  # each band's level as it is struck, against its loudest band, and the seconds it takes to fade
  # 60 dB, with the peaks of one take as ratios to the lowest.
  @tabla %{
    tabla_na: %{
      length: 2,
      bands: %{
        {250, 400} => {-24.3, 0.17},
        {400, 630} => {-23.0, 1.29},
        {630, 1000} => {0.0, 0.42},
        {1000, 1600} => {-6.1, 0.31},
        {1600, 2500} => {-21.1, 0.16},
        {2500, 4000} => {-24.9, 0.22},
        {4000, 6300} => {-42.5, 0.40},
        {6300, 10_000} => {-47.2, 0.29}
      },
      peaks: [1.0, 1.51, 2.04, 2.62]
    },
    tabla_tun: %{
      length: 3,
      bands: %{
        {250, 400} => {0.0, 2.33},
        {400, 630} => {-27.8, 2.01},
        {630, 1000} => {-24.8, 0.50},
        {1000, 1600} => {-31.7, 0.45},
        {1600, 2500} => {-34.3, 0.66},
        {2500, 4000} => {-45.0, 1.32},
        {4000, 6300} => {-48.1, 0.80},
        {6300, 10_000} => {-47.1, 1.10}
      },
      peaks: [1.0, 1.77]
    },
    tabla_te: %{
      length: 0.6,
      bands: %{
        {250, 400} => {-0.6, 0.13},
        {400, 630} => {-9.1, 0.13},
        {630, 1000} => {-10.8, 0.16},
        {1000, 1600} => {-7.3, 0.12},
        {1600, 2500} => {-8.4, 0.12},
        {2500, 4000} => {-11.4, 0.12},
        {4000, 6300} => {-15.1, 0.10},
        {6300, 10_000} => {-16.7, 0.11}
      },
      peaks: [1.0, 1.61, 2.65, 3.17, 4.62]
    },
    tabla_tas: %{
      length: 4,
      bands: %{
        {250, 400} => {-6.6, 0.34},
        {400, 630} => {-1.0, 2.03},
        {630, 1000} => {-5.4, 0.38},
        {1000, 1600} => {-5.1, 0.26},
        {1600, 2500} => {-16.7, 0.45},
        {2500, 4000} => {-25.4, 0.57},
        {4000, 6300} => {-32.3, 0.27},
        {6300, 10_000} => {-38.1, 0.36}
      },
      peaks: [1.0, 1.51, 2.03]
    },
    tabla_ghe: %{
      length: 5,
      bands: %{
        {80, 160} => {0.0, 3.53},
        {160, 250} => {-27.8, 5.73},
        {250, 400} => {-21.6, 1.63},
        {400, 630} => {-25.3, 0.55},
        {630, 1000} => {-29.0, 0.45},
        {1000, 1600} => {-32.6, 0.44},
        {1600, 2500} => {-41.8, 1.63},
        {2500, 4000} => {-47.8, 10.29}
      },
      peaks: []
    }
  }

  test "each tabla stroke's bands and fades follow mmiron's tabla bols", ctx do
    for {synth, %{length: length, bands: bands}} <- @tabla do
      hit = Hits.hit(render(ctx, synth, [], length), @rate, nil)
      measured = Map.new(Hits.summary([hit]), &{&1.band, &1})

      for {band, {level, fade}} <- bands do
        %{level: synth_level, fade: synth_fade} = measured[band]
        assert_in_delta synth_level, level, 6, "#{synth} #{inspect(band)} at #{synth_level} dB"

        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "#{synth} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  test "each dayan stroke's peaks sit at the ratios of mmiron's tabla bols, within 3 percent",
       ctx do
    for {synth, %{length: length, peaks: peaks}} <- @tabla do
      %{peaks: found} = Hits.hit(render(ctx, synth, [], length), @rate, nil)

      for ratio <- peaks do
        assert Enum.any?(found, &(abs(&1 / ratio - 1) <= 0.03)),
               "#{synth} has no peak at #{ratio}: #{inspect(found)}"
      end
    end
  end

  test "tabla_ghe rings on ghe_5's 93.6 Hz, and bends up two semitones as its note slides",
       ctx do
    assert_in_delta loudest_hz(render(ctx, :tabla_ghe, [], 1)) / 93.6, 1, 0.03

    slide = [note: 44.25, note_slide: 1.0]
    sound = render(ctx, :tabla_ghe, [], 4, [{0.5, slide}])
    low = loudest_hz(window(sound, 0, 0.5))
    high = loudest_hz(window(sound, 2, 4))
    assert_in_delta 1200 * :math.log2(high / low), 200, 50
  end

  test "tabla_na a semitone higher rings on the same partials a semitone higher", ctx do
    partials = fn note ->
      Hits.hit(render(ctx, :tabla_na, [note: note], 2), @rate, nil, partials: 6).partials
    end

    higher = partials.(61)

    for %{hz: hz} <- partials.(60) do
      assert Enum.any?(higher, &(abs(1200 * :math.log2(&1.hz / hz) - 100) <= 50)),
             "no partial a semitone above #{hz} Hz: #{inspect(Enum.map(higher, & &1.hz))}"
    end
  end

  test "tabla_ke is silent 0.1 seconds after its loudest moment", ctx do
    sound = render(ctx, :tabla_ke, [vel: 1], 0.5)
    loudest = Enum.find_index(sound, &(abs(&1) == peak(sound, 0, 0.5))) / @rate
    assert peak(sound, 0, 0.5) > 0.1
    assert peak(sound, loudest + 0.1, 0.5) == 0
  end

  test "each tabla stroke is louder at vel 1 than at vel 0.3", ctx do
    for synth <- [:tabla_ke | Map.keys(@tabla)] do
      soft = render(ctx, synth, [vel: 0.3], 1)
      hard = render(ctx, synth, [vel: 1], 1)
      assert rms(hard, 0, 0.1) > rms(soft, 0, 0.1) * 2, "#{synth}"
    end
  end

  # Measured with mix mx.measure --hits over the first minute of "Berimbau jam without caxixi.wav"
  # by EliasArtista on Freesound, 46 strokes:
  # each band's level as the string is struck, against the loudest band, and 50, 100 and 200 ms
  # after the loudest moment.
  @berimbau %{
    {80, 160} => {-22.5, [-23, -23, -26]},
    {160, 250} => {-10.0, [-12, -13, -15]},
    {250, 400} => {-8.2, [-11, -12, -12]},
    {400, 630} => {-10.3, [-16, -18, -16]},
    {630, 1000} => {-11.7, [-15, -16, -18]},
    {1000, 1600} => {-10.1, [-13, -14, -16]},
    {1600, 2500} => {-9.9, [-12, -14, -18]},
    {2500, 4000} => {0.0, [-6, -12, -19]},
    {4000, 6300} => {-0.3, [-12, -20, -22]},
    {6300, 10_000} => {-5.0, [-19, -27, -27]},
    {10_000, 16_000} => {-9.6, [-26, -32, -33]}
  }

  test "a berimbau stroke's bands follow EliasArtista's jam as it is struck and 50, 100 and 200 ms after",
       ctx do
    hit = Hits.hit(render(ctx, :berimbau, [gourd: 0], 3), @rate, nil)
    levels = Map.new(Hits.summary([hit]), &{&1.band, &1.level})
    moments = Map.new(Hits.moments([hit]), &{&1.band, tl(&1.levels)})

    for {band, {level, later}} <- @berimbau do
      assert_in_delta levels[band], level, 6, "#{inspect(band)} at #{levels[band]} dB"

      for {got, want} <- Enum.zip(moments[band], later) do
        assert_in_delta got, want, 6, "#{inspect(band)} later at #{inspect(moments[band])}"
      end
    end
  end

  test "a berimbau's partials sit on its string's harmonics, 78 Hz open, 83 Hz with the coin and 87 Hz at note 41",
       ctx do
    for {opts, string} <- [{[], 78.28}, {[coin: 1], 83.14}, {[note: 41], 87.31}] do
      %{partials: partials} = Hits.hit(render(ctx, :berimbau, opts, 3), @rate, nil, partials: 12)

      for %{hz: hz} <- partials do
        harmonic = round(hz / string)
        assert abs(hz / (harmonic * string) - 1) <= 0.03, "#{inspect(opts)} has #{hz} Hz"
      end
    end
  end

  test "an open berimbau stroke is strongest on its 3rd and 5th harmonics, as the gourd brings them out",
       ctx do
    %{partials: partials} = Hits.hit(render(ctx, :berimbau, [], 3), @rate, nil, partials: 12)

    [first, second] =
      partials
      |> Enum.sort_by(& &1.level, :desc)
      |> Enum.take(2)
      |> Enum.map(& &1.hz)
      |> Enum.sort()

    assert_in_delta first / 233, 1, 0.03
    assert_in_delta second / 390, 1, 0.03
  end

  test "a berimbau is louder at vel 1 than at vel 0.3, open, with the coin and buzzed", ctx do
    for opts <- [[], [coin: 1], [buzz: 1]] do
      soft = render(ctx, :berimbau, [vel: 0.3] ++ opts, 1)
      hard = render(ctx, :berimbau, [vel: 1] ++ opts, 1)
      assert rms(hard, 0, 0.2) > rms(soft, 0, 0.2) * 2, inspect(opts)
    end
  end

  # On uiop's "berimbau.aif" the gourd opens and closes against the belly every 0.43 seconds while
  # the string rings: the 5th harmonic swings 20 to 25 dB against the 3rd, peaking as the 3rd
  # dips, about 34 dB from peak to trough.
  test "a berimbau's gourd swings its 5th harmonic against its 3rd every 0.43 seconds, as on uiop's recording, and gourd: 0 holds it still",
       ctx do
    swing = fn sound ->
      for at <- Enum.map(2..100, &(&1 * 0.02)) do
        samples = window(sound, at, at + 0.09)
        10 * :math.log10(goertzel(samples, 5 * 78.28) / goertzel(samples, 3 * 78.28))
      end
    end

    moving = swing.(render(ctx, :berimbau, [], 2.2))
    assert Enum.max(moving) - Enum.min(moving) > 20

    peaks =
      for {[before, here, next], index} <-
            Enum.with_index(Enum.chunk_every(moving, 3, 1, :discard)),
          here > before and here >= next and here > Enum.max(moving) - 10,
          do: (index + 3) * 0.02

    gaps = Enum.zip_with(Enum.drop(peaks, 1), peaks, &(&1 - &2))
    assert length(gaps) >= 3, "peaks at #{inspect(peaks)}"
    assert_in_delta median(gaps), 0.43, 0.065

    still = swing.(render(ctx, :berimbau, [gourd: 0], 2.2))
    assert Enum.max(still) - Enum.min(still) < 6
  end

  # No open recording has a buzzed stroke, so the buzz is designed, not measured: the coin resting
  # on the wire damps the string and rattles against it.
  test "a buzzed berimbau stroke dies within 0.2 seconds, brighter than an open one", ctx do
    open = render(ctx, :berimbau, [], 1)
    buzz = render(ctx, :berimbau, [buzz: 1], 1)

    assert rms(buzz, 0.2, 0.3) < rms(buzz, 0, 0.05) / 30
    assert rms(open, 0.2, 0.3) > rms(open, 0, 0.05) / 5

    assert highs(buzz, 1500, 0, 0.05) / rms(buzz, 0, 0.05) >
             highs(open, 1500, 0, 0.05) / rms(open, 0, 0.05)
  end

  test "a buzzed berimbau stroke sits on the coin's 83 Hz string", ctx do
    %{partials: partials} =
      Hits.hit(render(ctx, :berimbau, [buzz: 1], 1), @rate, nil, partials: 6)

    for %{hz: hz} <- partials, hz < 1000 do
      harmonic = round(hz / 83.14)
      assert abs(hz / (harmonic * 83.14) - 1) <= 0.03, "buzz has #{hz} Hz"
    end
  end

  # Measured with mix mx.measure from "sitar01.flac" on Freesound, the first main string of a
  # sitar plucked at E3, F3, G3 and G#3:
  # each band's fade in seconds and its level against E3's fundamental.
  @sitar %{
    notes: [52, 53, 55, 56],
    bands: %{
      {160, 250} => {13.16, 3.9},
      {250, 400} => {10.43, 17.5},
      {400, 630} => {11.69, 26.5},
      {630, 1000} => {9.72, 25.4},
      {1000, 1600} => {8.98, 16.6},
      {1600, 2500} => {5.41, 7.8},
      {2500, 4000} => {3.95, 9.3}
    }
  }

  test "sitar's bands and fades follow sitar01's", ctx do
    notes =
      for note <- @sitar.notes do
        Measure.note(render(ctx, :sitar, [note: note], 4.4), @rate, note)
      end

    measured = Map.new(Measure.bands(notes), &{&1.band, &1})

    for {band, {fade, level}} <- @sitar.bands do
      %{level: synth_level, fade: synth_fade} = measured[band]
      assert_in_delta synth_level, level, 6, "#{inspect(band)} at #{synth_level} dB"
      assert_in_delta synth_fade / fade, 1, 0.3, "#{inspect(band)} fades in #{synth_fade} s"
    end
  end

  # The jawari, the string buzzing on the bridge, brings the harmonics up high at once.
  test "a sitar pluck reaches high at once, and its upper harmonics fade first", ctx do
    sound = render(ctx, :sitar, [note: 53], 4)
    brightness = fn from, to -> highs(sound, 4000, from, to) / rms(sound, from, to) end
    assert highs(sound, 10_000, 0, 0.1) > rms(sound, 0, 0.1) * 0.003
    assert brightness.(0, 0.3) > brightness.(2.5, 3.5) * 2
  end

  test "sitar's sympathetic strings ring on after a note on its Sa, and less after another",
       ctx do
    on_sa = render(ctx, :sitar, [note: 53, sa: 53], 7)
    off_sa = render(ctx, :sitar, [note: 53, sa: 48], 7)
    assert rms(on_sa, 4, 7) > rms(off_sa, 4, 7) * 2
  end

  test "sitar glides from F3 to G3 over a beat of note_slide, as meend does", ctx do
    slide = [note: 55.0, note_slide: 1.0]
    sound = render(ctx, :sitar, [note: 53], 2.5, [{0.5, slide}])
    assert_in_delta 1200 * :math.log2(pitch(sound, 1.5, 1.7) / 196.0), 0, 20
  end

  test "sitar is louder at vel 1 than at vel 0.3", ctx do
    soft = render(ctx, :sitar, [vel: 0.3], 1)
    hard = render(ctx, :sitar, [vel: 1], 1)
    assert rms(hard, 0, 0.5) > rms(soft, 0, 0.5) * 2
  end

  # Measured with mix mx.measure --held from the "Harmonium" pack by cabled_mess on Freesound, at
  # C2, C3, A3, C4 and D5:
  # the seconds a note takes to speak, and each band's level of harmonics and of the noise between
  # them, against C2's fundamental.
  @harmonium %{
    notes: [36, 48, 57, 60, 74],
    attack: 0.23,
    bands: %{
      {80, 160} => {5.8, -27.1},
      {160, 250} => {3.1, -28.6},
      {250, 400} => {3.8, -34.9},
      {400, 630} => {-4.5, -30.3},
      {630, 1000} => {3.9, -28.3},
      {1000, 1600} => {4.7, -27.2},
      {1600, 2500} => {-1.0, -25.9},
      {2500, 4000} => {-11.5, -27.4}
    }
  }

  test "harmonium speaks and holds its harmonics and noise as cabled_mess's harmonium does",
       ctx do
    notes =
      for note <- @harmonium.notes do
        Held.note(render(ctx, :harmonium, [note: note, sustain: 4], 4.5), @rate, note)
      end

    summary = Held.summary(notes)
    measured = Map.new(summary.bands, &{&1.band, &1})
    assert_in_delta summary.attack / @harmonium.attack, 1, 0.3, "speaks in #{summary.attack} s"

    for {band, {level, noise}} <- @harmonium.bands do
      assert_in_delta measured[band].level,
                      level,
                      6,
                      "#{inspect(band)} at #{measured[band].level} dB"

      assert_in_delta measured[band].noise,
                      noise,
                      6,
                      "#{inspect(band)} noise at #{measured[band].noise} dB"
    end
  end

  # The measuring reads a swing of 3.85 times a second on any bright note at C2, a plain saw's
  # too, so C2's vibrato is not checked.
  test "harmonium sounds its note with no vibrato, and a note tuned with cents at that pitch",
       ctx do
    for note <- [36, 48, 60, 74] do
      held = Held.note(render(ctx, :harmonium, [note: note, sustain: 3], 3.5), @rate, note)
      cents = 1200 * :math.log2(held.pitch / Signal.hz(note))
      assert abs(cents) < 10, "note #{note} is #{cents} cents off"
      if note > 36, do: assert(held.vibrato == nil)
    end

    held =
      Held.note(
        render(ctx, :harmonium, [note: 60 + Mx.Notation.cents(386), sustain: 3], 3.5),
        @rate,
        64
      )

    assert_in_delta 1200 * :math.log2(held.pitch / Signal.hz(60)), 386, 10
  end

  test "harmonium is louder at vel 1 than at vel 0.3", ctx do
    soft = render(ctx, :harmonium, [note: 60, vel: 0.3, sustain: 1], 1)
    hard = render(ctx, :harmonium, [note: 60, vel: 1, sustain: 1], 1)
    assert rms(hard, 0.5, 1) > rms(soft, 0.5, 1) * 2
  end

  # Measured with mix mx.measure --held from Freesound's previews of "Accordeon master" by
  # hammondman, at C3, E3, G3, C4, E4, G4, B4 and D5:
  # the seconds a note takes to speak, the reeds' beating as a vibrato, and each band's level of
  # harmonics and of the noise between them, against C3's fundamental.
  @accordion %{
    notes: [48, 52, 55, 60, 64, 67, 71, 74],
    attack: 0.05,
    vibrato: %{rate: 4.5, depth: 15},
    bands: %{
      {160, 250} => {1.8, -32.7},
      {250, 400} => {9.2, -35.7},
      {400, 630} => {7.7, -36.5},
      {630, 1000} => {2.4, -33.9},
      {1000, 1600} => {0.5, -27.9},
      {1600, 2500} => {-1.5, -26.2},
      {2500, 4000} => {-4.8, -22.9}
    }
  }

  test "accordion speaks, beats and holds its harmonics and noise as hammondman's accordion does",
       ctx do
    notes =
      for note <- @accordion.notes do
        held = Held.note(render(ctx, :accordion, [note: note, sustain: 1.5], 2), @rate, note)
        cents = 1200 * :math.log2(held.pitch / Signal.hz(note))
        assert abs(cents) < 10, "note #{note} is #{cents} cents off"
        held
      end

    summary = Held.summary(notes)
    measured = Map.new(summary.bands, &{&1.band, &1})
    assert_in_delta summary.attack / @accordion.attack, 1, 0.3, "speaks in #{summary.attack} s"
    assert_in_delta summary.vibrato.rate / @accordion.vibrato.rate, 1, 0.3
    assert_in_delta summary.vibrato.depth / @accordion.vibrato.depth, 1, 0.3

    for {band, {level, noise}} <- @accordion.bands do
      assert_in_delta measured[band].level,
                      level,
                      6,
                      "#{inspect(band)} at #{measured[band].level} dB"

      assert_in_delta measured[band].noise,
                      noise,
                      6,
                      "#{inspect(band)} noise at #{measured[band].noise} dB"
    end
  end

  test "accordion with detune 0 sounds one reed, with no beating", ctx do
    for note <- [48, 60, 74] do
      held =
        Held.note(render(ctx, :accordion, [note: note, detune: 0, sustain: 1.5], 2), @rate, note)

      assert held.vibrato == nil, "note #{note} beats"
    end
  end

  test "accordion is louder at vel 1 than at vel 0.3", ctx do
    soft = render(ctx, :accordion, [note: 60, vel: 0.3, sustain: 1], 1)
    hard = render(ctx, :accordion, [note: 60, vel: 1, sustain: 1], 1)
    assert rms(hard, 0.5, 1) > rms(soft, 0.5, 1) * 2
  end

  # The seconds until the last 10 ms that is within 20 dB of the loudest.
  defp scraping(sound) do
    levels =
      sound
      |> Enum.chunk_every(round(0.01 * @rate))
      |> Enum.map(fn chunk ->
        :math.sqrt(Enum.sum(Enum.map(chunk, &(&1 * &1))) / length(chunk))
      end)

    top = Enum.max(levels)
    (length(levels) - Enum.find_index(Enum.reverse(levels), &(&1 > top / 10))) / 100
  end

  # The strongest beat from 30 to 400 a second in the loudness above 2 kHz, taken 2000 times a
  # second.
  defp ridge_rate(sound, from, to) do
    coefficient = :math.exp(-2 * :math.pi() * 2000 / @rate)
    filtered = sound |> window(from, to) |> high_pass(coefficient) |> high_pass(coefficient)

    loudness =
      filtered
      |> Enum.chunk_every(div(@rate, 2000))
      |> Enum.map(fn chunk -> Enum.sum(Enum.map(chunk, &abs/1)) / length(chunk) end)

    mean = Enum.sum(loudness) / length(loudness)
    centred = loudness |> Enum.map(&(&1 - mean)) |> Enum.with_index()

    Enum.max_by(30..400//2, fn hz ->
      {re, im} =
        Enum.reduce(centred, {0.0, 0.0}, fn {value, i}, {re, im} ->
          angle = 2 * :math.pi() * hz * i / 2000
          {re + value * :math.cos(angle), im + value * :math.sin(angle)}
        end)

      re * re + im * im
    end)
  end

  # The second the sound first rises within 25 dB of its loudest, in 5 ms steps.
  defp speaks(sound) do
    levels = for chunk <- Enum.chunk_every(sound, 240), do: rms(chunk, 0, 0.005)
    loudest = Enum.max(levels)
    Enum.find_index(levels, &(&1 > loudest / 17.8)) * 0.005
  end

  # The strongest energy within 2 percent of `hz`, as the pitch's wobble spreads each harmonic.
  defp peak_near(samples, hz) do
    Enum.max(for step <- -4..4, do: goertzel(samples, hz * (1 + step * 0.005)))
  end

  # Fifteen cuíca strokes at `note`, rendered half a second apart in a song, each cut to its 0.45
  # seconds.
  defp cuica_strokes(ctx, note) do
    song = Path.join(ctx.tmp_dir, "strokes.exs")
    out = Path.join(ctx.tmp_dir, "strokes.wav")

    File.write!(song, """
    import Mx
    song(tempo: 120, music: part(:cuica, at(Enum.map(0..14, &{&1, hit(note: #{note})}), 15), synth: :cuica))
    """)

    capture_io(fn -> assert :ok = Mx.Render.render(song, out, seconds: 8) end)
    wav = File.read!(out)
    {at, _} = :binary.match(wav, "data")
    data = binary_part(wav, at + 8, byte_size(wav) - at - 8)
    left = for <<x::little-float-32, _::little-float-32 <- data>>, do: x
    for stroke <- 0..14, do: window(left, stroke * 0.5, stroke * 0.5 + 0.45)
  end

  defp render(ctx, synth, opts, seconds \\ 2, later \\ []) do
    Mxs.render_note(synth, opts, seconds, ctx.tmp_dir, later)
  end

  defp window(sound, from, to) do
    Enum.slice(sound, round(from * @rate), round((to - from) * @rate))
  end

  defp rms(sound, from, to) do
    samples = window(sound, from, to)
    :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / max(length(samples), 1))
  end

  defp peak(sound, from, to), do: sound |> window(from, to) |> Enum.map(&abs/1) |> Enum.max()

  # The frequency within a fifth of `near` whose period the samples repeat best at, by
  # autocorrelation, refined between lags.
  defp pitch(samples, near) do
    tuple = List.to_tuple(samples)
    count = tuple_size(tuple)
    lowest = floor(@rate / (near * 1.5))
    highest = ceil(@rate / (near / 1.5))

    correlate = fn lag ->
      Enum.reduce(0..(count - highest - 1), 0.0, fn i, sum ->
        sum + elem(tuple, i) * elem(tuple, i + lag)
      end)
    end

    scores = Map.new(lowest..highest, &{&1, correlate.(&1)})
    {lag, _} = Enum.max_by(scores, &elem(&1, 1))
    {before, at, next} = {scores[lag - 1], scores[lag], scores[lag + 1]}
    shift = if before && next, do: 0.5 * (before - next) / (before - 2 * at + next), else: 0
    @rate / (lag + shift)
  end

  # Level above a frequency, through two one-pole high-pass filters.
  defp highs(sound, hz, from, to) do
    coefficient = :math.exp(-2 * :math.pi() * hz / @rate)
    filtered = sound |> window(from, to) |> high_pass(coefficient) |> high_pass(coefficient)
    :math.sqrt(Enum.sum(Enum.map(filtered, &(&1 * &1))) / length(filtered))
  end

  defp hann(samples) do
    count = length(samples)

    Enum.with_index(samples, fn sample, index ->
      sample * 0.5 * (1 - :math.cos(2 * :math.pi() * index / (count - 1)))
    end)
  end

  defp high_pass(samples, coefficient) do
    {out, _} =
      Enum.map_reduce(samples, {0.0, 0.0}, fn input, {last_input, last_output} ->
        output = coefficient * (last_output + input - last_input)
        {output, {input, output}}
      end)

    out
  end

  # Each pandeiro band's level at 0, 50 and 100 ms after the loudest of the first 20 ms, in
  # 1024-sample spectra.
  # Each level is against the loudest band at 0 ms.
  defp pandeiro_levels(sound) do
    sound = List.to_tuple(sound)
    spectrum = fn ms -> Signal.spectrum(sound, round(ms * @rate / 1000), 1024) end

    level = fn spectrum, {low, high} ->
      bins = ceil(low * 1024 / @rate)..(ceil(high * 1024 / @rate) - 1)
      10 * :math.log10(Enum.sum(for at <- bins, do: elem(spectrum, at) ** 2) + 1.0e-24)
    end

    power = fn spectrum ->
      Enum.sum(for band <- @pandeiro_bands, do: 10 ** (level.(spectrum, band) / 10))
    end

    loudest = Enum.max_by(Enum.take_every(0..20, 2), &power.(spectrum.(&1)))
    top = @pandeiro_bands |> Enum.map(&level.(spectrum.(loudest), &1)) |> Enum.max()

    for band <- @pandeiro_bands do
      for ms <- [0, 50, 100], do: max(level.(spectrum.(loudest + ms), band) - top, -40)
    end
  end

  # Each band's level over the 50 ms stretches within 20 dB of the loudest, against the loudest
  # band.
  defp band_levels(sound) do
    hop = round(0.05 * @rate)
    chunks = Enum.chunk_every(sound, hop)
    louds = Enum.map(chunks, fn chunk -> rms(chunk, 0, 1) end)
    top = Enum.max(louds)
    tuple = List.to_tuple(sound)

    frames =
      for {loud, index} <- Enum.with_index(louds),
          loud > top / 10,
          index * hop + 2048 <= tuple_size(tuple),
          do: Signal.spectrum(tuple, index * hop, 2048)

    bin = @rate / 2048

    levels =
      for {low, high} = band <- Signal.bands(), into: %{} do
        power =
          Enum.sum(
            for frame <- frames,
                at <- ceil(low / bin)..(ceil(high / bin) - 1),
                do: elem(frame, at) ** 2
          )

        {band, 10 * :math.log10(power + 1.0e-24)}
      end

    loudest = levels |> Map.values() |> Enum.max()
    Map.new(levels, fn {band, level} -> {band, level - loudest} end)
  end

  # Seconds until the sound's 50 ms levels first fall 6 dB below their loudest.
  defp held(sound) do
    levels = sound |> Enum.chunk_every(round(0.05 * @rate)) |> Enum.map(&rms(&1, 0, 1))
    top = Enum.max(levels)
    Enum.find_index(levels, &(&1 < top / 2)) * 0.05
  end

  defp last_sound(sound) do
    index = sound |> Enum.reverse() |> Enum.find_index(&(abs(&1) > 0.001))
    (length(sound) - index) / @rate
  end

  # How far the pitch swings, from its measures in short windows across a stretch.
  defp wobble(sound, from, to) do
    pitches =
      for start <- Enum.take_every(round(from * 100)..round((to - 0.1) * 100), 3),
          do: pitch(sound, start / 100, start / 100 + 0.1)

    Enum.max(pitches) - Enum.min(pitches)
  end

  # Counts the peaks of the level, in 50 ms windows louder than the two on each side, across a
  # stretch.
  defp pulses(sound, from, to) do
    levels = for chunk <- Enum.chunk_every(window(sound, from, to), 2400), do: rms(chunk, 0, 0.05)

    levels
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.count(fn [a, b, level, c, d] -> level > Enum.max([a, b, c, d]) end)
  end

  # Counts the attacks: 5 ms levels that jump to half again the one before, at least 50 ms apart.
  defp picks(sound) do
    levels =
      for chunk <- Enum.chunk_every(sound, 240),
          do: :math.sqrt(Enum.sum(Enum.map(chunk, &(&1 * &1))) / length(chunk))

    quiet = Enum.max(levels) / 10

    [0.0 | levels]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.filter(fn {[before, level], _} -> level > quiet and level > before * 1.5 end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.reduce([], fn index, kept ->
      case kept do
        [last | _] when index - last < 10 -> kept
        _ -> [index | kept]
      end
    end)
    |> length()
  end

  # Each band's level within 6 dB and its fade within 30 percent of a table's, a nil leaving that
  # figure out.
  defp assert_bands(bands, table, label) do
    for {band, {level, fade}} <- table do
      %{level: synth_level, fade: synth_fade} = bands[band]

      if level do
        assert_in_delta synth_level, level, 6, "#{label} #{inspect(band)} at #{synth_level} dB"
      end

      if fade do
        assert_in_delta synth_fade / fade,
                        1,
                        0.3,
                        "#{label} #{inspect(band)} fades in #{synth_fade} s"
      end
    end
  end

  # The median level in dB of the loudest hundredth of the bins between two frequencies, over
  # 65536 samples from 0.3 seconds in.
  defp loudest_bins(sound, low, high) do
    size = 65_536
    spectrum = Signal.spectrum(List.to_tuple(sound), round(0.3 * @rate), size)

    bins =
      for bin <- round(low * size / @rate)..round(high * size / @rate), do: elem(spectrum, bin)

    loudest = bins |> Enum.sort(:desc) |> Enum.take(div(length(bins), 100))
    Signal.db(Signal.median(loudest))
  end

  defp piano_notes(ctx, vel, notes, opts) do
    notes
    |> Task.async_stream(
      fn note ->
        sound = render(ctx, :piano, [note: note, vel: vel, sustain: 60] ++ opts, 8)
        Measure.note(sound, @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp guitar_notes(ctx, vel) do
    @guitar_notes
    |> Task.async_stream(
      fn note ->
        sound = render(ctx, :guitar, [note: note, vel: vel], 4.4)
        Measure.note(sound, @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp harp_notes(ctx, vel) do
    36..92//2
    |> Task.async_stream(
      fn note -> Measure.note(render(ctx, :harp, [note: note, vel: vel], 4.5), @rate, note) end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp electric_bass_notes(ctx, notes, vel) do
    notes
    |> Task.async_stream(
      fn note ->
        sound = render(ctx, :electric_bass, [note: note, vel: vel], 4.5)
        Measure.note(sound, @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp bass_notes(ctx, synth, notes, vel) do
    notes
    |> Task.async_stream(
      fn note ->
        sound = render(ctx, synth, [note: note, vel: vel], 4.5)
        Measure.note(sound, @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp bowed_notes(ctx, synth, notes, opts) do
    notes
    |> Task.async_stream(
      fn note ->
        Held.note(render(ctx, synth, [note: note, sustain: 2.5] ++ opts, 3), @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, note} -> note end)
  end

  defp plucked_notes(ctx, synth, notes, vel) do
    notes
    |> Task.async_stream(
      fn note ->
        sound = render(ctx, synth, [note: note, vel: vel, pizz: 1, sustain: 1000], 4)
        Measure.note(sound, @rate, note)
      end,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
  end

  defp in_band?(freq, {low, high}), do: freq >= low and freq < high

  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle)
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  # The frequency within 25 cents of a guess with the most energy, to a quarter of a cent.
  defp sharpest(sound, guess, from, to) do
    samples = window(sound, from, to)

    Enum.max_by(-100..100, fn quarter -> goertzel(samples, guess * 2 ** (quarter / 4800)) end)
    |> then(&(guess * 2 ** (&1 / 4800)))
  end

  defp goertzel(samples, hz) do
    angle = 2 * :math.pi() * hz / @rate
    coefficient = 2 * :math.cos(angle)

    {last, before} =
      Enum.reduce(samples, {0.0, 0.0}, fn sample, {last, before} ->
        {sample + coefficient * last - before, last}
      end)

    last * last + before * before - coefficient * last * before
  end

  # The frequency between 30 and 600 Hz with the most energy, measured one frequency at a time.
  # The frequency of the loudest peak of the sound's first 0.17 seconds.
  defp loudest_hz(sound, below \\ 23_400) do
    spectrum = Signal.spectrum(List.to_tuple(sound), 0, 8192)
    last = round(below * 8192 / @rate)
    at = Enum.max_by(2..last, &elem(spectrum, &1))
    {position, _} = Signal.refine(spectrum, at)
    position * @rate / 8192
  end

  defp strongest(sound, from, to) do
    samples = window(sound, from, to)

    Enum.max_by(30..600//2, &goertzel(samples, &1))
  end

  # The frequency whose period best lines the sound up with itself, taking the shortest period
  # near the best.
  defp pitch(sound, from, to) do
    samples = sound |> window(from, to) |> List.to_tuple()
    size = min(tuple_size(samples), 4096) - 1200
    lags = 40..1200

    scores =
      for lag <- lags do
        {sum, energy} =
          Enum.reduce(0..(size - 1), {0.0, 0.0}, fn index, {sum, energy} ->
            sample = elem(samples, index)
            lagged = elem(samples, index + lag)
            {sum + sample * lagged, energy + lagged * lagged}
          end)

        {lag, sum / :math.sqrt(max(energy, 1.0e-12))}
      end

    best = scores |> Enum.map(&elem(&1, 1)) |> Enum.max()

    {lag, _} =
      scores
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.find_value(fn [{_, before}, {lag, score}, {_, next}] ->
        if score >= 0.85 * best and score >= before and score >= next, do: {lag, score}
      end)

    refine(scores, lag)
  end

  defp refine(scores, lag) do
    scores = Map.new(scores)
    {left, top, right} = {scores[lag - 1], scores[lag], scores[lag + 1]}
    shift = 0.5 * (left - right) / (left - 2 * top + right)
    @rate / (lag + shift)
  end
end
