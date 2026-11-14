defmodule Viola do
  @moduledoc """
  A solo for the viola written for mx, in C minor, from the ways a viola is played: a cantabile
  low on its C and G strings, the register that sets it apart from the violin, slurred in groups
  with its long notes swelled and eased; measured tremolo, the repeated sixteenths violas carry
  under an orchestra's melody, growing from soft to loud; arpeggios from the low C, slurred four
  notes to a bow across the strings; chords plucked and left to ring; and the melody an octave
  higher, settling on the low C, swelled.
  """

  use Mx.Song, tempo: 66

  part :viola, synth: :viola, fx: [reverb: [room: 0.5, mix: 0.25]]

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections = [:cantabile, :tremolo, :arpeggios, :pizz, :ending]

    Enum.with_index(sections, fn section, pass ->
      part(:viola, section(section, pass))
    end)
  end

  defp section(:cantabile, _pass), do: seq(melody(-12))

  # A note of the chord each half bar in repeated sixteenths, each its own short bow, from pp to
  # f.
  defp section(:tremolo, _pass) do
    line = [60, 63, 60, 65, 62, 65, 60, 63]

    seq(
      for {note, half} <- Enum.with_index(line), i <- 0..7 do
        vel = Float.round(0.35 + half * 0.07, 2)

        note(note, 0.25,
          vel: if(i == 0, do: Float.round(vel + 0.1, 2), else: vel),
          sustain: 0.2,
          release: 0.05,
          vibrato: 0
        )
      end
    )
  end

  # C minor, F minor, G seven and C minor up from the bass and back in sixteenths, four to a bow,
  # louder on each bar's first bow.
  defp section(:arpeggios, _pass) do
    chords = [[48, 55, 60, 63], [53, 56, 60, 65], [55, 59, 62, 65], [48, 55, 60, 63]]

    seq(
      for chord <- chords,
          {group, i} <-
            Enum.with_index(
              Enum.chunk_every(
                chord ++
                  Enum.map(chord, &(&1 + 12)) ++
                  Enum.reverse(Enum.map(chord, &(&1 + 12))) ++ Enum.reverse(chord),
                4
              )
            ) do
        bow(Enum.map(group, &{&1, 0.25}), if(i == 0, do: 0.75, else: 0.6), across: true)
      end
    )
  end

  # The same chords plucked in eighths, up and back down, each bar's bass note first and louder,
  # every note left to ring.
  defp section(:pizz, _pass) do
    chords = [[48, 55, 60, 63], [53, 56, 60, 65], [55, 59, 62, 65], [48, 55, 60, 63]]

    seq(
      for chord <- chords, {note, i} <- Enum.with_index(chord ++ Enum.reverse(chord)) do
        note(note, 0.5, vel: if(i == 0, do: 0.8, else: 0.6), pizz: 1, sustain: 4)
      end
    )
  end

  # The melody where it was written, its last note left for the low C, held and swelled.
  defp section(:ending, _pass) do
    seq(Enum.drop(melody(0), -1) ++ [bow([{48, 4}], 0.65, swell: true, vibrato: 0.08)])
  end

  # The melody as strokes, each a slur of {note, beats}, and whether its long note swells.
  defp melody(octave) do
    [
      {[{60, 1.5}, {62, 0.5}], false},
      {[{63, 1}, {67, 1}], false},
      {[{65, 2}], true},
      {[{63, 1}, {62, 1}], false},
      {[{63, 1.5}, {65, 0.5}], false},
      {[{67, 1}, {70, 1}], false},
      {[{67, 4}], true}
    ]
    |> Enum.map(fn {notes, swell} ->
      bow(Enum.map(notes, fn {note, beats} -> {note + octave, beats} end), 0.6,
        swell: swell,
        vibrato: 0.08
      )
    end)
  end

  # A stroke is notes as {note, beats} in one bow, the fingers changing its pitch; a shift of more
  # than a third slides audibly, as a player's finger does.
  # A swelled stroke grows louder to its middle and eases off to its end, and a stroke across the
  # strings changes note without sliding.
  defp bow([{first, held} | rest] = notes, vel, opts) do
    beats = Enum.sum(Enum.map(notes, &elem(&1, 1)))

    {fingers, _} =
      Enum.map_reduce(rest, {held, first}, fn {note, held}, {beat, previous} ->
        slide = if abs(note - previous) > 4 and !opts[:across], do: 0.08, else: 0.01
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
end
