import Mx

# Ernesto Nazareth's Odeon, a tango brasileiro of 1909 in C sharp minor: its first strain, played slowly by a choro regional.
# The melody is the pianist's left hand, low and singing, so the trombone sings it and the flute answers with the right hand's phrases; on the repeat the cello sings and the tenor saxophone answers.
# The notes are transcribed from Musica Brasilis' edition, revised against Nazareth's manuscript; the music itself is in the public domain.
defmodule Odeon do
  import Mx

  # The chord on each of the strain's 32 beats, two to a bar.
  def harmony do
    opening = [
      {:cs3, :minor},
      {:gs2, :major},
      {:cs3, :minor},
      {:cs3, :dom7},
      {:fs2, :minor},
      {:cs3, :dom7}
    ]

    first = [
      {:fs2, :minor},
      {:fs2, :minor},
      {:fs2, :minor},
      {:fs2, :minor},
      {:b2, :dom7},
      {:a2, :dom7},
      {:gs2, :dom7},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:cs3, :minor}
    ]

    second = [
      {:fs2, :minor},
      {:fs2, :half_dim7},
      {:ds3, :dim7},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:fs2, :minor},
      {:cs3, :minor},
      {:gs2, :dom7},
      {:cs3, :minor},
      {:cs3, :minor}
    ]

    opening ++ first ++ opening ++ second
  end

  # Choro's swing: the second sixteenth of a beat a little late, the fourth a little early, and every stroke a few milliseconds off.
  def feel(beat) do
    push = Enum.at([0, 0.02, 0, -0.02], rem(round(beat * 4), 4))
    max(beat + push + between(-0.01, 0.01), 0)
  end

  # A note held a dotted eighth and struck again a sixteenth before the next beat, the left hand's rhythm.
  def dotted(beat, note), do: [{beat, note, 0.75}, {beat + 0.75, note, 0.25}]

  # The left hand's melody as beat, note and beats held: down the scale from E3 to F#2, up the F sharp minor chord, down again from F#4, and the pickup to the next pass.
  def low do
    descent = Enum.with_index([52, 51, 49, 47, 45, 44], fn note, beat -> dotted(beat, note) end)

    climb = [
      {6, 42, 0.75},
      {6.75, 45, 0.25},
      {7, 49, 0.25},
      {7.25, 54, 0.25},
      {7.5, 57, 0.25},
      {7.75, 61, 0.25}
    ]

    fall = Enum.with_index([66, 64, 63, 61], fn note, beat -> dotted(8 + beat, note) end)

    pickup = fn beat ->
      [{beat + 0.25, 56, 0.25}, {beat + 0.5, 55, 0.25}, {beat + 0.75, 54, 0.25}]
    end

    again =
      Enum.with_index([52, 51, 49, 47, 45, 44, 42, 40], fn note, beat ->
        dotted(16 + beat, note)
      end)

    List.flatten([descent, climb, fall, dotted(12, 60), pickup.(15), again, pickup.(31)])
  end

  # The right hand's answers as beat, note and beats held: a turn over G#7 falling to C#m, then sighs a semitone down a sixteenth after each beat, settling on C#4.
  def answer do
    turn =
      [{13.25, 68, 0.25}, {13.5, 76, 0.25}, {13.75, 72, 0.25}] ++
        Enum.with_index([75, 73, 76, 73, 68, 64, 61, 60], fn note, i ->
          {14 + i * 0.25, note, 0.25}
        end)

    sighs =
      Enum.with_index([{69, 68}, {76, 75}, {75, 73}, {71, 69}, {69, 68}, {64, 63}], fn {from, to},
                                                                                       i ->
        [{24.25 + i, from, 0.5}, {24.75 + i, to, 0.25}]
      end)

    List.flatten([turn, sighs, {30, 61, 1.5}])
  end

  # Each note as its beat with the swing, note, vel and beats held: louder the higher it goes, softer on the sixteenths.
  def phrased(notes) do
    for {beat, note, held} <- notes do
      vel = 0.42 + (note - 40) * 0.006
      {feel(beat), note, Float.round(if(held < 0.3, do: vel * 0.85, else: vel), 2), held}
    end
  end

  # The melody is low on even passes, so the trombone sings and the flute answers; on odd ones the cello sings and the tenor saxophone answers.
  def trombone(pass) when rem(pass, 2) == 0 do
    entries =
      for {beat, note, vel, held} <- phrased(low()),
          do: {beat, note(note, held, vel: vel, sustain: held * 0.85, release: 0.15)}

    at(entries, 32)
  end

  def trombone(_pass), do: rest(32)

  def cello(pass) when rem(pass, 2) == 1 do
    entries =
      for {beat, note, vel, held} <- phrased(low()),
          do: {beat, note(note, held, vel: vel, sustain: held * 0.9, release: 0.2)}

    at(entries, 32)
  end

  def cello(_pass), do: rest(32)

  def flute(pass) when rem(pass, 2) == 0 do
    notes =
      for {beat, note, vel, held} <- phrased(answer()),
          do:
            {beat,
             note(note, held,
               vel: vel,
               sustain: held * 0.85,
               release: 0.15,
               vibrato: if(held > 0.4, do: 0.15, else: 0)
             )}

    at(notes, 32)
  end

  def flute(_pass), do: rest(32)

  def tenor_sax(pass) when rem(pass, 2) == 1 do
    notes =
      for {beat, note, vel, held} <- phrased(answer()),
          do:
            {beat,
             note(note, held,
               vel: Float.round(vel * 0.9, 2),
               sustain: held * 0.85,
               release: 0.15,
               vibrato: if(held > 0.4, do: 0.5, else: 0)
             )}

    at(notes, 32)
  end

  def tenor_sax(_pass), do: rest(32)

  # The 7-string guitar: the piano's chords off each beat while the melody is low, and the left hand's bass line while the melody is high.
  def guitar do
    chords = harmony()

    # Under the melody in the opening bars, above it where it climbs to F#4.
    offbeats =
      for beat <- Enum.to_list(0..11) ++ Enum.to_list(16..23),
          do: {feel(beat + 0.5), Enum.at(chords, beat), if(beat in 8..11, do: 66, else: 55)}

    offbeats =
      for {beat, {root, quality}, from} <- offbeats,
          do:
            {beat,
             note(voice(chord(root, quality), from: from, to: from + 11), 0.35,
               strum: 0.03,
               vel: between(0.3, 0.4),
               sustain: 0.35,
               release: 0.1
             )}

    bass =
      List.flatten([
        {12, 44, 1},
        {13, 39, 1},
        {14, 37, 1.25},
        dotted(24, 39),
        dotted(25, 44),
        dotted(26, 37),
        {27, 42, 0.75},
        {27.75, 43, 0.25},
        dotted(28, 44),
        dotted(29, 39),
        {30, 37, 1.5}
      ])

    bass =
      for {beat, note, _vel, held} <- phrased(bass),
          do:
            {beat,
             note(note, held,
               vel: if(held < 0.3, do: 0.5, else: 0.65),
               sustain: held * 0.9,
               release: 0.1
             )}

    at(offbeats ++ bass, 32)
  end

  # The cavaquinho strums close chords softly, down on the eighths and up on the sixteenths between, its pattern changing from bar to bar, and lets each strain's last chord ring.
  def cavaquinho do
    chords = harmony()

    patterns = [
      [{0, 0.45}, {0.5, 0.55}, {0.75, 0.35}, {1.25, 0.35}, {1.5, 0.55}],
      [{0.5, 0.55}, {0.75, 0.35}, {1.5, 0.55}, {1.75, 0.3}],
      [{0, 0.45}, {0.75, 0.45}, {1.5, 0.55}]
    ]

    strums =
      for bar <- 0..15,
          {offset, vel} <- if(bar in [7, 15], do: [{0, 0.5}], else: pick(patterns)) do
        {feel(bar * 2 + offset), Enum.at(chords, bar * 2 + trunc(offset)), vel,
         rem(round(offset * 4), 2) == 1, bar in [7, 15]}
      end

    strums =
      for {beat, {root, quality}, vel, up, last} <- strums do
        sustain = if last, do: 1.5, else: 0.2

        {beat,
         note(voice(chord(root, quality), from: 62, to: 73, limit: 4), sustain,
           strum: if(up, do: -0.02, else: 0.025),
           vel: Float.round(vel + between(-0.05, 0.05), 2),
           sustain: sustain,
           release: 0.1
         )}
      end

    at(strums, 32)
  end

  # The pandeiro, softly: thumb on the beat, its second beat stronger, fingertips on the second and fourth sixteenths, the heel on the third, now and then left out.
  def pandeiro_thumb do
    beats = Enum.map(0..31, &feel(&1 * 1.0))

    entries =
      for beat <- beats,
          do:
            {beat,
             hit(
               vel:
                 Float.round(
                   if(rem(round(beat), 2) == 0, do: 0.35, else: 0.6) + between(-0.05, 0.05),
                   2
                 )
             )}

    at(entries, 32)
  end

  def pandeiro_jingles do
    strokes = for beat <- 0..31, offset <- [0.25, 0.75], chance(0.9), do: feel(beat + offset)
    entries = for beat <- strokes, do: {beat, hit(vel: between(0.35, 0.55))}
    at(entries, 32)
  end

  def pandeiro_heel do
    strokes = for beat <- 0..31, chance(0.85), do: feel(beat + 0.5)
    entries = for beat <- strokes, do: {beat, hit(vel: between(0.4, 0.6))}
    at(entries, 32)
  end

  # A shaker under it all in sixteenths, down on each eighth and up between, barely there.
  def shaker do
    strokes = for sixteenth <- 0..127, do: {feel(sixteenth / 4), rem(sixteenth, 2)}

    entries =
      for {beat, up} <- strokes,
          do:
            {beat,
             hit(
               vel: Float.round(if(up == 0, do: 0.3, else: 0.18) + between(-0.04, 0.04), 2),
               up: up
             )}

    at(entries, 32)
  end
end

song(
  tempo: 72,
  music:
    together([
      part(:trombone, loop(32, fn pass, _ -> Odeon.trombone(pass) end),
        synth: :trombone,
        fx: [reverb: [room: 0.6, mix: 0.3]]
      ),
      part(:cello, loop(32, fn pass, _ -> Odeon.cello(pass) end),
        synth: :cello,
        fx: [reverb: [room: 0.6, mix: 0.3]]
      ),
      part(:flute, loop(32, fn pass, _ -> Odeon.flute(pass) end),
        synth: :flute,
        defaults: [amp: 1.1, pan: 0.2],
        fx: [reverb: [room: 0.6, mix: 0.3]]
      ),
      part(:tenor_sax, loop(32, fn pass, _ -> Odeon.tenor_sax(pass) end),
        synth: :tenor_sax,
        defaults: [pan: 0.2],
        fx: [reverb: [room: 0.6, mix: 0.3]]
      ),
      part(:guitar, loop(32, fn _, _ -> Odeon.guitar() end),
        synth: :guitar,
        defaults: [amp: 0.5, pan: -0.25],
        fx: [reverb: [room: 0.5, mix: 0.2]]
      ),
      part(:cavaquinho, loop(32, fn _, _ -> Odeon.cavaquinho() end),
        synth: :cavaquinho,
        defaults: [amp: 0.16, pan: 0.3],
        fx: [reverb: [room: 0.5, mix: 0.2]]
      ),
      part(:pandeiro_thumb, loop(32, fn _, _ -> Odeon.pandeiro_thumb() end),
        synth: :pandeiro_thumb,
        defaults: [amp: 0.35]
      ),
      part(:pandeiro_jingles, loop(32, fn _, _ -> Odeon.pandeiro_jingles() end),
        synth: :pandeiro_jingles,
        defaults: [amp: 0.2]
      ),
      part(:pandeiro_heel, loop(32, fn _, _ -> Odeon.pandeiro_heel() end),
        synth: :pandeiro_heel,
        defaults: [amp: 0.28]
      ),
      part(:shaker, loop(32, fn _, _ -> Odeon.shaker() end),
        synth: :shaker,
        defaults: [amp: 0.22, pan: -0.35]
      )
    ])
)
