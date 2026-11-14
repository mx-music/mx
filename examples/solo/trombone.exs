defmodule Trombone do
  @moduledoc """
  A solo for the trombone written for mx: a legato melody in F major whose notes glide into each
  other as the slide moves, a march in short notes, a long note at its softest and then its
  loudest, and a last glide from F2 up to F4.
  """

  use Mx.Song, tempo: 76

  part :trombone, synth: :trombone

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [legato: 2, march: 1, extremes: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      part(:trombone, trombone(section, pass))
    end)
  end

  # A pass of the trombone, as 16 beats; each legato phrase is one note its changes move, as the
  # slide moves without a new breath.
  defp trombone(section, pass) do
    if section in [:legato, :ending] do
      glides =
        for {beat, held, vel, slide, [{0, first} | rest]} <- glides(section, pass) do
          changes = for {at, next} <- rest, do: {at, note: next}
          {beat, note(first, held, vel: vel, release: 0.3, note_slide: slide, changes: changes)}
        end

      at(glides, 16)
    else
      notes =
        for {beat, note, vel, opts} <- strokes(section),
            do: {beat, note(note, Keyword.get(opts, :sustain, 0), [vel: vel] ++ opts)}

      at(notes, 16)
    end
  end

  # Each glided phrase as its beat, beats held, vel, the beats each glide takes, and its notes as
  # beat after the phrase starts and note.
  defp glides(:legato, pass) do
    for {beat, notes} <- [
          {0, [{0, 53}, {2, 58}, {3, 57}]},
          {4, [{0, 55}, {2, 53}]},
          {8, [{0, 50}, {1, 53}, {2, 58}]},
          {12, [{0, 57}, {2, 53}]}
        ],
        do: {beat, 3.7, 0.6, 0.3, Enum.map(notes, fn {at, note} -> {at, note - pass * 5} end)}
  end

  # F2 held, then sliding up two octaves to F4 and holding it, loud.
  defp glides(:ending, _pass), do: [{0, 15, 0.9, 2, [{0, 41}, {4, 65}]}]

  defp strokes(:march) do
    for {beat, note} <- march() do
      if beat == 14 do
        {beat, note, 0.8, sustain: 1.5, release: 0.3}
      else
        {beat, note, 0.8, sustain: 0.25, release: 0.05}
      end
    end
  end

  # F3 then Bb3 held at its softest, then the same at its loudest, with some vibrato.
  defp strokes(:extremes) do
    for {vel, from} <- [{0.2, 0}, {1, 8}],
        {beat, note} <- [{0, 53}, {4, 58}],
        do: {from + beat, note, vel, sustain: 3.6, release: 0.3, vibrato: 0.1}
  end

  # The march as beat and note, in short notes but for the last, which is held.
  defp march do
    [
      {0, 46},
      {1, 53},
      {1.5, 53},
      {2, 50},
      {3, 46},
      {4, 48},
      {5, 50},
      {5.5, 51},
      {6, 53},
      {8, 58},
      {9, 57},
      {9.5, 55},
      {10, 53},
      {11, 51},
      {12, 50},
      {13, 48},
      {14, 46}
    ]
  end
end
