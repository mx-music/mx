defmodule Mx.Notes do
  @moduledoc """
  Note names, chords and scales, worked out as plain MIDI note numbers.

  A note name is a letter from a to g, upper or lower case, an optional `s` for sharp or `b` for flat, and an optional octave that defaults to 4, so `:c4` is 60, middle C.
  Chords and scales are lists of note numbers, built from a root given as a name or a number, and a scale ends on the octave above its root.
  """

  @letters %{"c" => 0, "d" => 2, "e" => 4, "f" => 5, "g" => 7, "a" => 9, "b" => 11}

  @chords %{
    major: [0, 4, 7],
    minor: [0, 3, 7],
    dim: [0, 3, 6],
    aug: [0, 4, 8],
    dom7: [0, 4, 7, 10],
    major7: [0, 4, 7, 11],
    minor7: [0, 3, 7, 10],
    sus2: [0, 2, 7],
    sus4: [0, 5, 7],
    dim7: [0, 3, 6, 9],
    half_dim7: [0, 3, 6, 10],
    major6: [0, 4, 7, 9],
    minor6: [0, 3, 7, 9],
    dom7_flat9: [0, 4, 7, 10, 13],
    dom9: [0, 4, 7, 10, 14]
  }

  # Each scale is the steps between its notes, in semitones, up to the octave.
  @scales %{
    major: [2, 2, 1, 2, 2, 2, 1],
    minor: [2, 1, 2, 2, 1, 2, 2],
    major_pentatonic: [2, 2, 3, 2, 3],
    minor_pentatonic: [3, 2, 2, 3, 2],
    dorian: [2, 1, 2, 2, 2, 1, 2],
    mixolydian: [2, 2, 1, 2, 2, 1, 2],
    blues: [3, 2, 1, 1, 3, 2],
    harmonic_minor: [2, 1, 2, 2, 1, 3, 1],
    chromatic: List.duplicate(1, 12)
  }

  @doc "A note number for a number or a note name such as `:c4`, raising `ArgumentError` for an unknown name."
  def note(number) when is_number(number), do: number

  def note(name) when is_atom(name) and name not in [nil, true, false] do
    parse(Atom.to_string(name))
  end

  @doc "The note number for text giving a number or a note name, such as \"60\" or \"c4\", raising `ArgumentError` for neither."
  def from_text(text) when is_binary(text) do
    case Integer.parse(text) do
      {number, ""} -> number
      _ -> parse(text)
    end
  end

  @doc "The note number for a note name written as text, such as \"A2\", raising `ArgumentError` for an unknown name."
  def parse(text) when is_binary(text) do
    case Regex.run(~r/^([a-gA-G])([sb]?)(-?\d*)$/, text) do
      [_, letter, accidental, octave] ->
        octave = if octave == "", do: 4, else: String.to_integer(octave)
        shift = %{"" => 0, "s" => 1, "b" => -1}[accidental]
        12 * (octave + 1) + @letters[String.downcase(letter)] + shift

      nil ->
        raise ArgumentError, "unknown note #{text}"
    end
  end

  @doc "The notes of a chord, from a root given as a name or a number."
  def chord(root, name) when (is_number(root) or is_atom(root)) and is_atom(name) do
    root = note(root)
    Enum.map(fetch!(@chords, name, "chord"), &(root + &1))
  end

  @doc "The notes of a scale from a root, ending on the octave above it, over `octaves:` octaves (1 by default)."
  def scale(root, name, opts \\ [])
      when (is_number(root) or is_atom(root)) and is_atom(name) and is_list(opts) do
    steps = fetch!(@scales, name, "scale")
    octaves = Keyword.get(opts, :octaves, 1)
    steps = steps |> List.duplicate(octaves) |> List.flatten()
    Enum.scan(steps, note(root), &(&1 + &2)) |> then(&[note(root) | &1])
  end

  @doc "The step from each note to the next, from notes given as names or numbers."
  def intervals(notes) when is_list(notes) do
    notes = Enum.map(notes, &note/1)
    Enum.zip_with(notes, Enum.drop(notes, 1), &(&2 - &1))
  end

  @doc "The notes reached by taking each step in turn from a start note given as a name or a number."
  def melody(start, steps) when (is_number(start) or is_atom(start)) and is_list(steps) do
    start = note(start)
    [start | Enum.scan(steps, start, &(&1 + &2))]
  end

  @doc "The note of a chord, in any octave, closest to a note, the lower on a tie; `except:` leaves out one note."
  def nearest(note, chord, opts \\ [])
      when (is_integer(note) or is_atom(note)) and is_list(chord) and is_list(opts) do
    note = note(note)
    except = Keyword.get(opts, :except)

    candidates =
      for tone <- chord,
          shift <- [-12, 0, 12],
          candidate = note - Integer.mod(note - tone, 12) + shift,
          candidate != except,
          do: candidate

    Enum.min_by(candidates, &{abs(&1 - note), &1})
  end

  @doc "The note of a chord, in any octave, closest below a note."
  def below(note, chord) when (is_integer(note) or is_atom(note)) and is_list(chord) do
    note = note(note)
    Enum.max(for tone <- chord, do: note - (Integer.mod(note - tone - 1, 12) + 1))
  end

  @doc "Each note of a chord placed once from `from:` up to `to:`, leaving out the root of a chord of more notes than `limit:`."
  def voice(chord, opts) when is_list(chord) and is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    limit = Keyword.get(opts, :limit, length(chord))
    tones = if length(chord) > limit, do: tl(chord), else: chord
    placed = tones |> Enum.map(&(from + Integer.mod(&1 - from, 12))) |> Enum.uniq() |> Enum.sort()

    if List.last(placed) > to do
      chord = inspect(chord, charlists: :as_lists)
      raise ArgumentError, "voice cannot place every note of #{chord} from #{from} to #{to}"
    end

    placed
  end

  @doc "A scale bent to a chord: each chord tone missing from the scale takes the place of the scale note a semitone below it, or a semitone above when there is none below."
  def fit(scale, chord) when is_list(scale) and is_list(chord) do
    chord
    |> Enum.map(&Integer.mod(&1, 12))
    |> Enum.uniq()
    |> Enum.reduce(scale, fn tone, scale ->
      classes = Enum.map(scale, &Integer.mod(&1, 12))

      cond do
        tone in classes -> scale
        Integer.mod(tone - 1, 12) in classes -> shift(scale, tone - 1, 1)
        Integer.mod(tone + 1, 12) in classes -> shift(scale, tone + 1, -1)
        true -> scale
      end
    end)
  end

  defp shift(scale, class, step) do
    Enum.map(scale, &if(Integer.mod(&1 - class, 12) == 0, do: &1 + step, else: &1))
  end

  defp fetch!(table, name, kind) do
    case Map.fetch(table, name) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "unknown #{kind} #{name}"
    end
  end
end
