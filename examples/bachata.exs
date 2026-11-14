defmodule LunaDeCabarete do
  @moduledoc """
  Luna de Cabarete, a bachata in A minor at 126 bpm, written for mx and not transcribed from any
  record.
  It is played by bachata's five instruments: the requinto, the lead guitar, the segunda, the
  rhythm guitar, the bass, the bongos and the güira.
  The rhythms are the genre's usual ones for each section.
  In the derecho, the verse, the bongos and the güira play every eighth, the bongos louder on one
  and three and on the large drum on four; in the majao, the chorus, they play the beats alone,
  the güira in longer scrapes; in the mambo the güira plays one, the and of two, three and the and
  of four, and the bongos play freely.
  The segunda plays a bass note on one, three and four and strums the chord on two and on every
  eighth off the beat, and the bass plays one, the and of two, three and four, in every section.
  The requinto sings the verse, plays the chorus in two voices over a tune that steps down three
  notes to a bar, long, long, short, and in the mambo plays the chords one note to an eighth.
  Both guitars are Karoryfer's Shinyguitar, an archtop, and the bass is Karoryfer's Swagbass, both
  under Creative Commons 0; the bongos are mx's, and the güira is mx's cabasa, steel beads turned
  on a steel cylinder, since mx has no güira.
  The files, about 150 MB, are fetched as the song loads.
  """

  use Mx.Song, tempo: 126

  @guitar :karoryfer_shiny_guitar
  @bass :karoryfer_swag_bass

  # The guitar through its microphone, a note every minor third, at four strengths and two takes
  # of each.
  @guitar_keys ~w(e2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 gb4 a4 c5 eb5 gb5 a5 c6)
  @shinyguitar Enum.flat_map(@guitar_keys, fn name ->
                 for strength <- 1..4, take <- 1..2 do
                   path = "Samples/acoustic/#{name}_vl#{strength}_rr#{take}_1.wav"

                   {{@guitar, path}, note: Mx.Notes.parse(name), strength: strength, take: take}
                 end
               end)

  # Swagbass names each note an octave above the pitch it sounds.
  @bass_keys ~w(a1 c2 eb2 gb2 a2 c3 eb3 gb3 a3 c4)
  @swagbass Enum.flat_map(@bass_keys, fn name ->
              for {dynamic, strength} <- [{"p", 1}, {"f", 2}], take <- 1..2 do
                path = "notes/#{name}_#{dynamic}_rr#{take}.wav"

                {{@bass, path}, note: Mx.Notes.parse(name) - 12, strength: strength, take: take}
              end
            end)

  @room [reverb: [room: 0.6, damp: 0.5, mix: 0.2]]

  part :requinto,
    synth: sampled(@shinyguitar),
    defaults: [release: 0.3],
    fx: [
      hpf: [cutoff: 55],
      level: [amp: 1.0],
      chorus: [phase: 1.5, mix: 0.35],
      echo: [phase: 0.75, decay: 1.5, mix: 0.12],
      reverb: [room: 0.7, damp: 0.4, mix: 0.25],
      pan: [pan: 0.2]
    ]

  part :second_voice,
    synth: sampled(@shinyguitar),
    defaults: [release: 0.3],
    fx: [
      hpf: [cutoff: 55],
      level: [amp: 0.7],
      chorus: [phase: 1.5, mix: 0.35],
      reverb: [room: 0.7, damp: 0.4, mix: 0.25],
      pan: [pan: 0.45]
    ]

  part :segunda, synth: sampled(@shinyguitar), fx: [level: [amp: 0.9], pan: [pan: -0.35]] ++ @room
  part :bass, synth: sampled(@swagbass), defaults: [release: 0.1], fx: [level: [amp: 2.8]]
  part :macho, synth: :high_bongo, fx: [level: [amp: 2.8], pan: [pan: -0.15]] ++ @room
  part :hembra, synth: :low_bongo, fx: [level: [amp: 2.5], pan: [pan: -0.1]] ++ @room
  part :guira, synth: :cabasa, fx: [level: [amp: 1.1], pan: [pan: 0.3]] ++ @room

  def song do
    seq([intro(), verse(), chorus(), mambo(), verse(), chorus(), chorus(), ending()])
  end

  # The requinto alone plays the chorus's last four bars, and the bongos roll into the verse.
  defp intro do
    together([
      part(:requinto, hook(4..7)),
      part(:second_voice, thirds(4..7)),
      bongos([:silence, :silence, :silence, :roll])
    ])
  end

  # The derecho: the requinto sings eight bars over A minor, D minor and E seventh.
  defp verse do
    chords = ~w(am dm e7 am am dm e7 am)a

    together([
      part(:requinto, tune()),
      part(:segunda, segunda(chords)),
      part(:bass, bass(chords)),
      bongos(List.duplicate(:derecho, 7) ++ [:roll]),
      part(:guira, guira(:derecho, 8))
    ])
  end

  # The majao: the hook in two voices, down through F, G, C and A minor, then D minor and E
  # seventh home.
  defp chorus do
    chords = ~w(f g c am dm e7 am am)a

    together([
      part(:requinto, hook(0..7)),
      part(:second_voice, thirds(0..7)),
      part(:segunda, segunda(chords)),
      part(:bass, bass(chords)),
      bongos(List.duplicate(:majao, 7) ++ [:roll]),
      part(:guira, guira(:majao, 8))
    ])
  end

  # The mambo: A minor, G, F and E seventh twice round, the requinto one note to an eighth, and
  # the second time two strings together over it.
  defp mambo do
    chords = ~w(am g f e7 am g f e7)a

    together([
      part(:requinto, repeat(riff(), 2)),
      part(:second_voice, delay(double_stops(), 16)),
      part(:segunda, segunda(chords)),
      part(:bass, bass(chords)),
      bongos(~w(derecho repique derecho offbeats derecho repique offbeats roll)a),
      part(:guira, guira(:mambo, 8))
    ])
  end

  # The cierre: everyone plays one bar of E seventh together, and stops on A minor.
  defp ending do
    together([
      part(:requinto, plucked([~MX"e5 gs5 b5 gs5 e5 d5 b4 gs4", ~MX"a4:8"], 0.85)),
      part(:second_voice, plucked([~MX"gs4 b4 d5 b4 gs4 e4 d4 b3", ~MX"e4:8"], 0.7)),
      part(
        :segunda,
        steps(~MX"e2/b2/e3/gs3/d4/e4:8 a2/e3/a3/c4/e4:8", 0.5, vel: 0.55, strum: 0.03, release: 2)
      ),
      part(:bass, steps(~MX"e1:2 e1:2 gs1:2 b1:2 a1:8", 0.5, vel: 0.6, release: 1.5)),
      bongos([:roll, :last]),
      part(:guira, steps(~MX"L...L...L...L.SSL..............."s, 0.25, strokes: scrapes()))
    ])
  end

  # Bars of the chorus's tune, counted from 0, an eighth to a step: three notes to a bar that step
  # down, the first two held for three eighths.
  defp hook(bars) do
    hook = [
      ~MX"a5:3 g5:3 f5:2",
      ~MX"g5:3 f5:3 d5:2",
      ~MX"e5:3 d5:3 c5:2",
      ~MX"c5:3 b4:3 a4:2",
      ~MX"f5:3 e5:3 d5:2",
      ~MX"e5:3 d5:3 b4:2",
      ~MX"a4:3 c5 e5 a5:3",
      ~MX"_:5 e5 f5 g5"
    ]

    plucked(Enum.slice(hook, bars), 0.85)
  end

  # The voice under the hook, a third or a sixth below it.
  defp thirds(bars) do
    thirds = [
      ~MX"f5:3 e5:3 d5:2",
      ~MX"e5:3 d5:3 b4:2",
      ~MX"c5:3 b4:3 a4:2",
      ~MX"a4:3 g4:3 e4:2",
      ~MX"d5:3 c5:3 a4:2",
      ~MX"gs4:3 b4:3 gs4:2",
      ~MX"e4:3 a4 c5 e5:3",
      ~MX"_:8"
    ]

    plucked(Enum.slice(thirds, bars), 0.7)
  end

  # The verse's tune: a phrase that climbs the chord and falls back, asked twice and answered.
  defp tune do
    plucked(
      [
        ~MX"_ e5 a5 b5 c6:2 b5 a5",
        ~MX"a5:3 f5 d5:4",
        ~MX"_ e5 gs5 a5 b5:2 a5 gs5",
        ~MX"a5:3 e5 c5:4",
        ~MX"_ e5 a5 b5 c6:2 b5 a5",
        ~MX"a5:3 f5 d5:2 f5:2",
        ~MX"e5 gs5 b5 gs5 e5 d5 b4 gs4",
        ~MX"a4:5 e5 f5 g5"
      ],
      0.8
    )
  end

  # The mambo's four bars: each chord up and back, a note to an eighth.
  defp riff do
    plucked(
      [
        ~MX"a4 c5 e5 a5 e5 c5 e5 a5",
        ~MX"g4 b4 d5 g5 d5 b4 d5 g5",
        ~MX"f4 a4 c5 f5 c5 a4 c5 f5",
        ~MX"e4 gs4 b4 e5 gs5 e5 d5 b4"
      ],
      0.75
    )
  end

  # Two strings together on one, the and of two and four, where the güira scrapes.
  defp double_stops do
    plucked(
      [
        ~MX"c5/e5:3 e5/a5:3 c5/e5:2",
        ~MX"b4/d5:3 d5/g5:3 b4/d5:2",
        ~MX"a4/c5:3 c5/f5:3 a4/c5:2",
        ~MX"gs4/b4:3 b4/e5:3 d5/gs5:2"
      ],
      0.8
    )
  end

  # The segunda's bar for each chord, an eighth to a step: a bass note on one, three and four,
  # and the chord strummed short between.
  defp segunda(chords) do
    bars = %{
      am: ~MX"a2 a3/c4/e4 a3/c4/e4 a3/c4/e4 e3 a3/c4/e4 a2 a3/c4/e4",
      dm: ~MX"d3 a3/d4/f4 a3/d4/f4 a3/d4/f4 a2 a3/d4/f4 d3 a3/d4/f4",
      e7: ~MX"e2 gs3/d4/e4 gs3/d4/e4 gs3/d4/e4 b2 gs3/d4/e4 e2 gs3/d4/e4",
      f: ~MX"f2 a3/c4/f4 a3/c4/f4 a3/c4/f4 c3 a3/c4/f4 f2 a3/c4/f4",
      g: ~MX"g2 g3/b3/d4 g3/b3/d4 g3/b3/d4 d3 g3/b3/d4 g2 g3/b3/d4",
      c: ~MX"c3 g3/c4/e4 g3/c4/e4 g3/c4/e4 g2 g3/c4/e4 c3 g3/c4/e4"
    }

    stroke = fn step ->
      if rem(step, 8) in [0, 4, 6] do
        [vel: 0.62 + wobble(step, 0.05), sustain: 0.45, release: 0.3]
      else
        loud = if rem(step, 8) == 2, do: 0.55, else: 0.45
        [vel: loud + wobble(step, 0.05), strum: 0.02, sustain: 0.2, release: 0.12]
      end
    end

    steps(Enum.map(chords, &bars[&1]), 0.5, each: stroke)
  end

  # The bass's bar for each chord, an eighth to a step: the root on one and again on the and of
  # two, the third on three and the fifth on four.
  defp bass(chords) do
    bars = %{
      am: ~MX"a1:3 a1 c2:2 e2:2",
      dm: ~MX"d2:3 d2 f2:2 a2:2",
      e7: ~MX"e1:3 e1 gs1:2 b1:2",
      f: ~MX"f1:3 f1 a1:2 c2:2",
      g: ~MX"g1:3 g1 b1:2 d2:2",
      c: ~MX"c2:3 c2 e2:2 g2:2"
    }

    pluck = fn step, length ->
      loud = if rem(step, 8) == 0, do: 0.75, else: 0.6
      [vel: loud + wobble(step, 0.04), sustain: length / 2 - 0.1]
    end

    steps(Enum.map(chords, &bars[&1]), 0.5, each: pluck)
  end

  # The bongos' bars, each named by what it plays.
  defp bongos(bars) do
    strokes = [
      O: [vel: 0.85],
      o: [vel: 0.65],
      t: [muted: 1, vel: 0.4],
      g: [muted: 1, vel: 0.55]
    ]

    drum = fn drum ->
      steps(Enum.map(bars, fn bar -> bongo(bar)[drum] end), 0.25, strokes: strokes)
    end

    together([part(:macho, drum.(:macho)), part(:hembra, drum.(:hembra))])
  end

  # A bar of the two drums in sixteenths: O is an open tone, o a softer one, g a muted stroke of
  # the finger and t a soft one of the thumb.
  defp bongo(:derecho) do
    %{macho: ~MX"O.t.g.t.O.t...t."s, hembra: ~MX"............O..."s}
  end

  defp bongo(:majao) do
    %{macho: ~MX"O...o...O......."s, hembra: ~MX"............O..."s}
  end

  # Accents every third sixteenth over soft strokes.
  defp bongo(:repique) do
    %{macho: ~MX"OttOttOttOttO.t."s, hembra: ~MX"..............O."s}
  end

  defp bongo(:offbeats) do
    %{macho: ~MX"..O...O...O.t.t."s, hembra: ~MX"O...........O.O."s}
  end

  # The derecho with a roll on four that passes from the small drum to the large one.
  defp bongo(:roll) do
    %{macho: ~MX"O.t.g.t.O.t.ooo."s, hembra: ~MX"...............O"s}
  end

  defp bongo(:last), do: %{macho: ~MX"o..............."s, hembra: ~MX"o..............."s}
  defp bongo(:silence), do: %{macho: ~MX"................"s, hembra: ~MX"................"s}

  # The güira's bar in sixteenths, for each section.
  defp guira(section, bars) do
    bar = %{
      derecho: ~MX"S.ssS.ssS.ssS.ss"s,
      majao: ~MX"L...L...L...L..."s,
      mambo: ~MX"L.....S.L.....S."s
    }

    repeat(steps(bar[section], 0.25, strokes: scrapes()), bars)
  end

  # L is a long scrape, S a short one and s a short one back.
  defp scrapes do
    [
      L: [vel: 0.7, rub: 1, sustain: 0.45],
      S: [vel: 0.65, rub: 1, sustain: 0.16],
      s: [vel: 0.55, rub: 1, sustain: 0.12]
    ]
  end

  # Bars of a guitar's line, an eighth to a step, the note on each beat picked a little harder.
  defp plucked(bars, vel) do
    pick = fn step ->
      accent = if rem(step, 2) == 0, do: 0.05, else: -0.03
      [vel: min(vel + accent + wobble(step, 0.04), 1)]
    end

    steps(bars, 0.5, each: pick)
  end

  # A small amount, up to `size` either way, that is the same each time for the same `seed`.
  defp wobble(seed, size), do: (:erlang.phash2(seed, 1000) / 999 - 0.5) * 2 * size
end
