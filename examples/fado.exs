defmodule Fado do
  @moduledoc """
  Fado menor, the traditional fado in a minor key, as Manoel Gomes printed it for the Portuguese
  guitar in A Guitarra Portuguesa: Método fácil, Lisbon, 1929, anonymous and long in the public
  domain.
  It is played as a fado house plays it: the guitarra portuguesa leads, the viola, a guitar,
  strums the chords, and the viola baixo, an acoustic bass, plays on the beats.
  The guitarra's notes are read from Ronald Louis Fernández's tablature of Gomes's score,
  transposed from F minor to D minor for the modern Lisbon tuning: the theme and three variations,
  in 2/4, in sixteenths.
  The harmony is the fado menor's, D minor and A7 by turns, and the third variation passes through
  E flat before its last A7.
  There is no free recording of a guitarra, so it is Karoryfer's Shinyguitar, an archtop under
  Creative Commons 0, played twice for each note as a guitarra's paired strings sound: the second
  string a few cents sharp and a moment late, in unison on the three top courses and an octave up
  on the three below.
  The viola is the same guitar through its microphone, and the viola baixo Karoryfer's Sneakybass,
  also under Creative Commons 0.
  The guitarra plays the theme, the three variations and the theme again, slowing at the end of
  each eight bars as a fadista breathes; the files, about 140 MB, are fetched as the song loads.
  """

  use Mx.Song, tempo: 66

  @guitar :karoryfer_shiny_guitar
  @bass :karoryfer_sneaky_bass

  # The guitar through its microphone, a note every minor third, at four strengths and two takes
  # of each.
  @guitar_keys ~w(e2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 gb4 a4 c5 eb5 gb5)
  @shinyguitar Enum.flat_map(@guitar_keys, fn name ->
                 for strength <- 1..4, take <- 1..2 do
                   path = "Samples/acoustic/#{name}_vl#{strength}_rr#{take}_1.wav"

                   {{@guitar, path}, note: Mx.Notes.parse(name), strength: strength, take: take}
                 end
               end)

  # Sneakybass names each note an octave above the pitch it sounds.
  @bass_keys ~w(c2 db2 d2 eb2 e2 f2 gb2 g2 ab2 a2 bb2 b2 c3 db3 d3 eb3 e3)
  @sneakybass Enum.flat_map(@bass_keys, fn name ->
                for take <- 1..2 do
                  path = "Samples/finger/sneakybass_#{name}_finger_rr#{take}.wav"

                  {{@bass, path}, note: Mx.Notes.parse(name) - 12, take: take}
                end
              end)

  @room [reverb: [room: 0.55, damp: 0.5, mix: 0.2]]

  part :guitarra,
    synth: sampled(@shinyguitar),
    fx: [hpf: [cutoff: 76, mix: 0.45], level: [amp: 0.95], pan: [pan: 0.25]] ++ @room

  part :viola,
    synth: sampled(@shinyguitar),
    fx: [level: [amp: 0.42], pan: [pan: -0.3]] ++ @room

  # Sneakybass's recordings rumble below its lowest note, which the high-pass takes out.
  part :baixo, synth: sampled(@sneakybass), fx: [hpf: [cutoff: 28], level: [amp: 0.6]] ++ @room
  part :tempo, []

  def song do
    seq(
      [intro(), theme(0.66, 66), variation(1, 0.74), variation(2, 0.68), variation(3, 0.78)] ++
        [theme(0.6, 60), ending()]
    )
  end

  # The guitarra alone leads into the theme.
  defp intro, do: part(:guitarra, guitarra(:pickup, 0.6))

  # The theme, seven bars after the lead-in: D minor and A7 by turns.
  defp theme(vel, bpm) do
    period(guitarra(:theme, vel), ~w(dm a7 a7 dm dm a7 a7)a, vel, bpm)
  end

  defp variation(3, vel) do
    period(guitarra(3, vel), ~w(dm dm a7 a7 dm dm eb a7)a, vel, 66)
  end

  defp variation(number, vel) do
    period(guitarra(number, vel), ~w(dm dm a7 a7 dm dm a7 a7)a, vel, 66)
  end

  # The last bar: the guitarra's arpeggio stops on the low D, and the viola's chord rings on.
  defp ending do
    together([
      part(:guitarra, guitarra(:last, 0.6)),
      part(
        :viola,
        steps(~MX"d3 a3/d4/f4 d3/a3/d4/f4:6", 0.5, strum: 0.05, sustain: 3, release: 1.5)
      ),
      part(:baixo, steps(~MX"d3:2 d2:4", 0.5, vel: 0.6, sustain: 2.5, release: 1)),
      part(:tempo, at([{0, tempo(54, over: 2)}], 4))
    ])
  end

  # Eight bars or seven: the guitarra over the viola and the viola baixo, slowing into the last
  # bar.
  defp period(guitarra, chords, vel, bpm) do
    beats = 2 * length(chords)

    together([
      part(:guitarra, guitarra),
      part(:viola, viola(chords, vel - 0.12)),
      part(:baixo, baixo(chords, vel)),
      part(:tempo, at([{0, tempo(bpm)}, {beats - 2, tempo(bpm - 9, over: 2)}], beats))
    ])
  end

  # The guitarra's bars, a sixteenth to a word, as Fernández's tablature has them.
  defp guitarra(:pickup, vel), do: plucked([~MX"_:4 bb4 a3 a4:2"], vel)

  defp guitarra(:theme, vel) do
    tonic = ~MX"d3 f4 a3 d4 d3 bb4 a3 a4"
    dominant = ~MX"e3 g4 a3 cs4 e3 bb4 a3 a4"
    plucked([tonic, dominant, dominant, tonic, tonic, dominant, dominant], vel)
  end

  # Variation 1: the melody on the first course, an open A between its notes.
  defp guitarra(1, vel) do
    plucked(
      [
        ~MX"d3 f4 a3 d4 d3 a4 f4 a4",
        ~MX"f5 a4 f5 a4 e5 a4 d5 a4",
        ~MX"e3 g4 a3 cs4 e3 a4 cs5 a4",
        ~MX"e5 a4 e5 a4 d5 a4 cs5 a4",
        ~MX"d3 f4 a3 d4 d3 a4 f4 a4",
        ~MX"f5 a4 f5 a4 e5 a4 d5 a4",
        ~MX"e3 g4 a3 cs4 e3 a4 bb4 a4",
        ~MX"g4 a4 f4 a4 e4 a4 d4 cs4"
      ],
      vel
    )
  end

  # Variation 2: a bass that climbs chromatically from A into a run up the scale.
  defp guitarra(2, vel) do
    climb = ~MX"d3 f4 a3 d4 d3 a3 bb3 b3"
    run = ~MX"c4 d4 f4 e4 g4 f4 c5 bb4"

    plucked(
      [
        climb,
        run,
        ~MX"e3 g4 a3 cs4 e3 e4 f4 fs4",
        ~MX"g4 a4 bb4 a4 c5 bb4 a4 g4",
        climb,
        run,
        ~MX"e3 g4 a3 cs4 e3 bb4 g4 bb4",
        ~MX"a4 e4 g4 d4 f4 cs4 e4 f4"
      ],
      vel
    )
  end

  # Variation 3: arpeggios down from the top, and E flat, the chord a semitone above the key,
  # before the last A7.
  defp guitarra(3, vel) do
    tonic = ~MX"d3 f4 a3 d4 d3:2 a4:2"

    plucked(
      [
        tonic,
        ~MX"d5 a4 f4 d4 a4 f4 d4 a3",
        ~MX"e3 g4 a3 cs4 e3:2 a4:2",
        ~MX"e5 cs5 a4 e4 g4 e4 cs4 a3",
        tonic,
        ~MX"f5 d5 a4 f4 d4 a3 f3 d3",
        ~MX"eb3 g3 bb3 eb4 g4 bb4 eb5 d5",
        ~MX"cs5:3 a4 bb4 a4 e4 f4"
      ],
      vel
    )
  end

  defp guitarra(:last, vel), do: plucked([~MX"d3 f4 a3 d4 d3:4"], vel)

  # The viola's bar: the thumb on the beats, the bass and then its fifth, and the chord struck
  # short on each eighth between.
  defp viola(chords, vel) do
    bars = %{
      dm: ~MX"d3 a3/d4/f4 a2 a3/d4/f4",
      a7: ~MX"a2 g3/cs4/e4 e3 g3/cs4/e4",
      eb: ~MX"eb3 g3/bb3/eb4 bb2 g3/bb3/eb4"
    }

    chord = fn step -> if rem(step, 2) == 0, do: thumb(vel, step), else: strum(vel, step) end
    steps(Enum.map(chords, &bars[&1]), 0.5, each: chord)
  end

  defp thumb(vel, step), do: [vel: vel + 0.08 + wobble(step, 0.04), sustain: 0.45, release: 0.3]

  defp strum(vel, step) do
    [vel: vel - 0.08 + wobble(step, 0.04), strum: 0.025, sustain: 0.22, release: 0.12]
  end

  # The viola baixo on the beats: the chord's root, then its fifth below.
  defp baixo(chords, vel) do
    bars = %{dm: ~MX"d3 a2", a7: ~MX"a2 e3", eb: ~MX"eb3 bb2"}
    loud = fn step -> [vel: vel + wobble(step, 0.05), sustain: 0.8, release: 0.3] end
    steps(Enum.map(chords, &bars[&1]), 1, each: loud)
  end

  # The guitarra's bars, each note on two strings: the second a few cents sharp and a moment late,
  # an octave up below the third course.
  defp plucked(bars, vel) do
    first = steps(bars, 0.25, each: &dedilho(vel, &1))
    second = steps(Enum.map(bars, &paired/1), 0.25, each: &dedilho(vel * 0.62, &1))

    together([
      swing(first, &placed/1),
      swing(transpose(second, cents(5)), &(placed(&1) + 0.006))
    ])
  end

  # How hard each note of a bar of sixteenths is plucked: the beat hardest, the eighths between
  # next and the rest softest; the beats' notes, mostly basses, ring longer.
  defp dedilho(vel, step) do
    weight =
      case rem(step, 8) do
        0 -> 0.1
        4 -> 0.06
        n when rem(n, 2) == 0 -> 0
        _ -> -0.05
      end

    rings = if rem(step, 4) == 0, do: 0.9, else: 0.45
    [vel: min(vel + weight + wobble(step, 0.06), 1), sustain: rings, release: 0.3]
  end

  # The second string of a note's course: an octave up on the courses tuned below E4.
  defp paired(bar) do
    Enum.map(bar, fn cell ->
      %{cell | tokens: Enum.map(cell.tokens, &octave_string/1)}
    end)
  end

  defp octave_string(name) do
    if Mx.Notes.parse(name) < pitch(:e4) do
      String.replace(name, ~r/\d$/, fn octave ->
        Integer.to_string(String.to_integer(octave) + 1)
      end)
    else
      name
    end
  end

  # Where a player puts a note written at `beat`, never quite on it.
  defp placed(beat), do: max(beat + wobble(beat, 0.01), 0)

  # A small amount, up to `size` either way, that is the same each time for the same `seed`.
  defp wobble(seed, size), do: (:erlang.phash2(seed, 1000) / 999 - 0.5) * 2 * size
end
