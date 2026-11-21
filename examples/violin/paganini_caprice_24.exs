defmodule Paganini do
  @moduledoc """
  Paganini's Caprice No. 24 in A minor, from his 24 Caprices for solo violin, op. 1 (1817): the
  theme and its first variation, each half repeated.
  The notes follow the ABC transcription "Paganini Caprice" at abcnotation.com, tune 10047 of
  Lester Bailey's collection.
  A note is its name, then after a colon its length as a score writes it: 4 a quarter, 8 an
  eighth, 16 a sixteenth, 12 an eighth in a triplet, and a dot adds half.
  A note without a length keeps the one before it, r is a rest, parentheses slur notes into one
  bow stroke, and < starts a crescendo to the end.
  """

  use Mx.Song, tempo: 116

  part :violin, synth: :violin, fx: [reverb: [room: 0.5, mix: 0.3]]

  def song do
    repeat(
      form([theme_a: 2, theme_b: 2, variation_a: 2, variation_b: 2], fn section ->
        part(:violin, seq(Enum.map(phrases(score(section)), &bow/1)))
      end)
    )
  end

  # The notes of a score, each slur gathered into one list and every other note in a list of its
  # own.
  defp phrases(score) do
    tokens =
      for bar <- String.split(score, ["|", "\n"], trim: true),
          {token, i} <- Enum.with_index(String.split(bar)),
          do: {token, i == 0}

    {notes, _} = Enum.map_reduce(tokens, {0, 0}, &read/2)
    Enum.chunk_while(notes, [], &slur/2, fn [] -> {:cont, []} end)
  end

  defp score(:theme_a) do
    """
    a4:8. a4:16 (a4 c5 b4 a4) | e5:8. e4:16 (e4 gs4 fs4 e4) | a4:8. a4:16 (a4 c5 b4 a4) | e5:4 e4:8 r
    """
  end

  defp score(:theme_b) do
    """
    a5:8. a5:16 (a5 bb5 a5 g5) | f5:8. d5:16 (d5 f5 e5 d5) | g5:8. g5:16 (g5 a5 g5 f5) | e5:8. c5:16 (c5 e5 d5 c5)
    f5:8. b4:16 (b4 d5 c5 b4) | e5:8. a4:16 (a4 c5 b4 a4) | f4:8. ds5:16 (e4 e5 d5 b4) | a4:4 a3:8 r
    """
  end

  defp score(:variation_a) do
    """
    e5:12 c5 a4 c5 e5 a5 | b5 gs5 e5 b4 gs4 e4 | a4 c5 e5 a5 e5 c5 | e5:4 e4:8 r
    """
  end

  defp score(:variation_b) do
    """
    a5:12 e5 cs5 a4 e4 cs4 | d4 e4 a4 d5 f5 a5 | g5 d5 b4 g4 d4 b3 | c4 e4 g4 c5 e5 g5
    f5 d5 b4 gs4 e4 <d5 | c5 e5 c5 a4 e4 c4 | d4 f4 a4 e4 e5 gs5 | a4:4 a3:8 r
    """
  end

  defp bow([%{note: nil, beats: beats}]), do: rest(beats)

  # A detached note is bowed to the next one with a change of bow between, and only a long one
  # takes vibrato.
  defp bow([note]) do
    vibrato = if note.beats >= 1, do: 0.2, else: 0
    sustain = Float.round(note.beats * 0.85, 3)
    note(note.note, note.beats, vel: vel(note), sustain: sustain, release: 0.15, vibrato: vibrato)
  end

  # A slur is one stroke whose pitch the fingers change, sliding audibly only on a shift of more
  # than a third.
  defp bow([first | rest] = slur) do
    beats = Enum.sum(Enum.map(slur, & &1.beats))

    {changes, _} =
      Enum.map_reduce(rest, {first.beats, first.note}, fn note, {beat, previous} ->
        slide = if abs(pitch(note.note) - pitch(previous)) > 4, do: 0.06, else: 0.01
        {{beat, note: note.note, note_slide: slide}, {beat + note.beats, note.note}}
      end)

    note(first.note, beats,
      vel: vel(first),
      sustain: beats - 0.1,
      release: 0.1,
      vibrato: 0,
      changes: changes
    )
  end

  defp read({token, downbeat}, {length, louder}) do
    [_, open, crescendo, name, value, dot, close] =
      Regex.run(~r/^(\(?)(<?)([a-g][sb]?\d|r)(?::(\d+)(\.?))?(\)?)$/, token)

    length = if value == "", do: length, else: 4 / String.to_integer(value)
    length = if dot == ".", do: length * 1.5, else: length
    louder = if crescendo == "<" or louder > 0, do: louder + 1, else: 0
    note = if name == "r", do: nil, else: pitch(name)

    {%{
       note: note,
       beats: length,
       open: open == "(",
       close: close == ")",
       accent: downbeat,
       louder: louder
     }, {length, louder}}
  end

  defp slur(%{open: true} = note, []), do: {:cont, [note]}
  defp slur(note, []), do: {:cont, [note], []}
  defp slur(%{close: true} = note, slur), do: {:cont, Enum.reverse([note | slur]), []}
  defp slur(note, slur), do: {:cont, [note | slur]}

  # Louder on the first note of a bar and through a crescendo.
  defp vel(note) do
    accent = if note.accent, do: 0.15, else: 0
    Float.round(clamp(0.6 + accent + note.louder * 0.02, 0, 0.95), 2)
  end
end
