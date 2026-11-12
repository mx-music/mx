import Mx

# A solo for the violin written for mx, in D minor, from the ways a violin is played:
# a cantabile slurred in groups, each long note swelled and eased, the messa di voce Leopold Mozart's Violinschule (1756) teaches;
# bariolage, stopped notes against the open A string, the figure of the Preludio of Bach's Partita No. 3, played détaché, the second time louder;
# the melodic minor scale over two octaves slurred eight notes to a bow, then arpeggios in short notes off the string;
# chords plucked down to the open G string; and a climb on audible shifts to a long D7 with vibrato.

defmodule Violin do
  import Mx

  # A stroke is notes as {note, beats} in one bow, the fingers changing its pitch; a shift of more than a third slides audibly, as a player's finger does.
  # A swelled stroke grows louder to its middle and eases off to its end.
  def bow([{first, held} | rest] = notes, vel, opts \\ []) do
    beats = Enum.sum(Enum.map(notes, &elem(&1, 1)))

    {fingers, _} =
      Enum.map_reduce(rest, {held, first}, fn {note, held}, {beat, previous} ->
        slide = if abs(note - previous) > 4, do: 0.08, else: 0.01
        {{beat, note: note, note_slide: slide}, {beat + held, note}}
      end)

    # A note repeated in a slur is held on, with no change.
    fingers =
      for {{beat, change}, previous} <- Enum.zip(fingers, Enum.map(notes, &elem(&1, 0))),
          change[:note] != previous,
          do: {beat, change}

    {start, swell} =
      if opts[:swell] do
        {[amp: 0.6],
         [{0, amp: 1, amp_slide: beats / 2}, {beats / 2, amp: 0.5, amp_slide: beats / 2}]}
      else
        {[], []}
      end

    note(
      first,
      beats,
      [vel: vel] ++
        start ++
        [
          sustain: beats - 0.1,
          release: 0.15,
          vibrato: Keyword.get(opts, :vibrato, 0),
          changes: Enum.sort_by(fingers ++ swell, &elem(&1, 0))
        ]
    )
  end

  def section(:cantabile, _pass) do
    seq([
      bow([{62, 2}], 0.5, swell: true, vibrato: 0.08),
      bow([{65, 0.5}, {64, 0.5}, {62, 0.5}, {69, 0.5}], 0.5),
      bow([{69, 1}, {74, 2}], 0.55, vibrato: 0.08),
      bow([{72, 0.5}, {70, 0.5}], 0.5),
      bow([{69, 1.5}, {67, 0.5}], 0.5, vibrato: 0.08),
      bow([{65, 0.5}, {67, 0.5}, {69, 0.5}, {70, 0.5}], 0.5),
      bow([{69, 4}], 0.55, swell: true, vibrato: 0.08)
    ])
  end

  # Each beat a note of the line on the D string, the open A, the line again and the A, every note its own bow.
  def section(:bariolage, pass) do
    line = [77, 76, 74, 73, 74, 76, 77, 79, 77, 76, 74, 72, 70, 72, 73, 76]
    louder = 0.1 * (pass - 1)

    seq(
      for note <- line, {pitch, i} <- Enum.with_index([note, 69, note, 69]) do
        vel = if i == 0, do: 0.65 + louder, else: 0.5 + louder
        note(pitch, 0.25, vel: vel, sustain: 0.2, release: 0.05, vibrato: 0)
      end
    )
  end

  # Up the melodic minor and down the natural minor in sixteenths, eight to a bow, louder going up; then the four chords as arpeggios in short eighths.
  def section(:scales, _pass) do
    up = [62, 64, 65, 67, 69, 71, 73, 74, 76, 77, 79, 81, 83, 85, 86, 86]
    down = [86, 84, 82, 81, 79, 77, 76, 74, 72, 70, 69, 67, 65, 64, 62, 62]

    slurs =
      for {group, index} <- Enum.with_index(Enum.chunk_every(up ++ down, 8)) do
        bow(Enum.map(group, &{&1, 0.25}), Enum.at([0.5, 0.65, 0.7, 0.55], index))
      end

    arpeggios = [62, 65, 69, 74, 67, 70, 74, 79, 69, 73, 76, 79, 74, 77, 81, 86]

    short =
      for note <- arpeggios,
          do: note(note, 0.5, vel: 0.6, sustain: 0.12, release: 0.05, vibrato: 0)

    seq(slurs ++ short)
  end

  # The chords plucked in eighths, each bar's lowest note first and louder, down to the open G, every note left to ring.
  def section(:pizz, _pass) do
    chords = [{62, [65, 69, 74]}, {55, [62, 67, 70]}, {57, [61, 64, 67]}, {62, [65, 69, 74]}]

    seq(
      for {bass, chord} <- chords do
        notes = [bass | chord] ++ tl(Enum.reverse(chord)) ++ [bass + 7]

        plucks =
          Enum.with_index(
            notes,
            &note(&1, 0.5, vel: if(&2 == 0, do: 0.8, else: 0.6), pizz: 1, sustain: 4)
          )

        seq(plucks ++ [rest(0.5)])
      end
    )
  end

  # Shifting up the A and E strings in one bow, then D7 held, swelled and eased, with vibrato.
  def section(:ending, _pass) do
    seq([
      bow([{74, 1}, {81, 1}, {86, 1}, {89, 0.5}, {88, 0.5}], 0.6),
      bow([{98, 8}], 0.7, swell: true, vibrato: 0.1),
      rest(4)
    ])
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [cantabile: 1, bariolage: 2, scales: 1, pizz: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:violin, section(section, pass), synth: :violin, fx: [reverb: [room: 0.5, mix: 0.25]])
    end)
  end
end

song(tempo: 72, music: repeat(seq(Violin.form())))
