# A solo for the cello written for mx, in G major, from the ways a cello is played:
# the opening bars of the Prelude of Bach's Cello Suite No. 1, chords broken across the strings in
# sixteenths, slurred eight notes to a bow;
# a cantabile in the cello's tenor, climbing from the G string to the A string on shifts that
# slide audibly, its long notes swelled and eased, with vibrato;
# a walking bass line plucked, the cellist's pizzicato in jazz; and a climb high on the A string,
# falling back to the low G, swelled.
defmodule Cello do
  use Mx.Song, tempo: 66

  part :cello, synth: :cello, fx: [reverb: [room: 0.5, mix: 0.25]]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections = [:prelude, :cantabile, :pizz, :ending]

    Enum.with_index(sections, fn section, pass ->
      part(:cello, section(section, pass))
    end)
  end

  # Each bar's eight notes played twice, over the open G: G major, C over G, D seven over G and G
  # major again.
  defp section(:prelude, _pass) do
    bars = [
      [43, 50, 59, 57, 59, 50, 59, 50],
      [43, 52, 60, 59, 60, 52, 60, 52],
      [43, 54, 60, 59, 60, 54, 60, 54],
      [43, 55, 59, 57, 59, 55, 59, 54]
    ]

    seq(
      for bar <- bars, i <- 0..1 do
        bow(Enum.map(bar, &{&1, 0.25}), if(i == 0, do: 0.65, else: 0.55), across: true)
      end
    )
  end

  # Each stroke a slur of {note, beats}, and whether its long note swells.
  defp section(:cantabile, _pass) do
    [
      {[{50, 1.5}, {55, 0.5}], false},
      {[{59, 2}], true},
      {[{57, 1}, {55, 0.5}, {57, 0.5}], false},
      {[{62, 2}], true},
      {[{64, 1}, {62, 0.5}, {60, 0.5}], false},
      {[{59, 1}, {67, 1}], false},
      {[{66, 1}, {64, 0.5}, {62, 0.5}], false},
      {[{62, 2}], true}
    ]
    |> Enum.map(fn {notes, swell} -> bow(notes, 0.6, swell: swell, vibrato: 0.08) end)
    |> seq()
  end

  # G, E minor, C and D seven, walking in quarters, each bar's root louder, every note left to
  # ring under the next.
  defp section(:pizz, _pass) do
    line = [43, 47, 50, 47, 40, 43, 47, 45, 36, 40, 43, 45, 38, 42, 45, 42]

    seq(
      Enum.with_index(line, fn note, i ->
        note(note, 1, vel: if(rem(i, 4) == 0, do: 0.8, else: 0.6), pizz: 1, sustain: 2)
      end)
    )
  end

  # Up the A string in one bow to a long high D, then down by the arpeggio to the low G, held and
  # swelled.
  defp section(:ending, _pass) do
    seq([
      bow([{62, 1}, {66, 1}, {69, 1}, {71, 0.5}, {72, 0.5}], 0.65),
      bow([{74, 3}], 0.7, swell: true, vibrato: 0.1),
      bow([{67, 0.5}, {62, 0.5}], 0.6),
      bow([{59, 1}, {55, 1}, {50, 1}, {47, 1}], 0.6, across: true),
      bow([{43, 4}], 0.7, swell: true, vibrato: 0.08)
    ])
  end

  # A stroke is notes as {note, beats} in one bow, the fingers changing its pitch; a shift of more
  # than a third slides audibly, as a player's finger does.
  # A swelled stroke grows louder to its middle and eases off to its end, and a stroke across the
  # strings changes note without sliding.
  defp bow([{first, held} | rest] = notes, vel, opts \\ []) do
    beats = Enum.sum(Enum.map(notes, &elem(&1, 1)))

    {fingers, _} =
      Enum.map_reduce(rest, {held, first}, fn {note, held}, {beat, previous} ->
        slide = if abs(note - previous) > 4 and !opts[:across], do: 0.1, else: 0.01
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
          release: 0.2,
          vibrato: Keyword.get(opts, :vibrato, 0),
          changes: Enum.sort_by(fingers ++ swell, &elem(&1, 0))
        ]
    )
  end
end
