defmodule DoubleBass do
  @moduledoc """
  A solo for the double bass written for mx: a plucked walking line through a twelve-bar blues in
  F, four bars at a time, then a slow bowed melody over its low strings, and a last walk down to
  its low F, bowed and held.
  """

  use Mx.Song, tempo: 112

  part :double_bass, synth: :double_bass

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections = for {section, count} <- [walk: 3, bowed: 1, ending: 1], _ <- 1..count, do: section

    Enum.with_index(sections, fn section, pass ->
      part(:double_bass, double_bass(section, pass))
    end)
  end

  # A pass of the form as its 16 beats: each stroke at its beat, lasting its sustain.
  defp double_bass(section, pass) do
    strokes =
      for {beat, note, vel, opts} <- strokes(section, pass),
          do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

    at(strokes, 16)
  end

  # Each bar walks up the root, third and fifth in quarters, and steps to a semitone below the
  # next bar's root; the beat is plucked harder.
  defp strokes(:walk, pass) do
    bars = bars()

    for bar <- 0..3,
        at = pass * 4 + bar,
        {root, third} = Enum.at(bars, at),
        {next, _third} = Enum.at(bars, rem(at + 1, 12)),
        {note, beat} <- Enum.with_index([root, root + third, root + 7, next - 1]) do
      {bar * 4 + beat, note, if(beat == 0, do: 0.8, else: 0.6), pizz: 1, sustain: 0.9}
    end
  end

  # A melody in half and whole notes, slurred in two bows that swell and ease, with vibrato, the
  # second sliding down to the low C.
  defp strokes(:bowed, _pass) do
    [
      {0, 41, 0.65,
       sustain: 7.8,
       release: 0.4,
       vibrato: 0.08,
       amp: 0.6,
       changes: [
         {0, amp: 1, amp_slide: 4},
         {4, note: 45, note_slide: 0.01},
         {6, note: 43, note_slide: 0.01},
         {4, amp: 0.6, amp_slide: 4}
       ]},
      {8, 41, 0.65,
       sustain: 7.8,
       release: 0.4,
       vibrato: 0.08,
       amp: 0.6,
       changes: [
         {0, amp: 1, amp_slide: 4},
         {4, note: 36, note_slide: 0.15},
         {4, amp: 0.5, amp_slide: 4}
       ]}
    ]
  end

  # A plucked walk down from F2, a step a beat, to the low F, bowed and held.
  defp strokes(:ending, _pass) do
    walk =
      Enum.with_index([41, 39, 38, 36, 34, 33, 31, 30], fn note, beat ->
        {beat, note, 0.7, pizz: 1, sustain: 0.9}
      end)

    walk ++
      [
        {8, 29, 0.8,
         sustain: 6,
         release: 1,
         vibrato: 0.08,
         amp: 0.6,
         changes: [{0, amp: 1, amp_slide: 3}, {3, amp: 0.5, amp_slide: 3}]}
      ]
  end

  # The blues's roots, a bar each, with the third each chord takes; G is minor.
  defp bars do
    [
      {29, 4},
      {34, 4},
      {29, 4},
      {29, 4},
      {34, 4},
      {34, 4},
      {29, 4},
      {38, 4},
      {31, 3},
      {36, 4},
      {29, 4},
      {36, 4}
    ]
  end
end
