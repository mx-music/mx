defmodule Mx.Notes do
  @moduledoc """
  Note names, chords and scales, worked out as plain MIDI note numbers.

  A note name is a letter from a to g, upper or lower case, an optional `s` for sharp or `b` for
  flat, and an optional octave that defaults to 4, so `:c4` is 60, middle C.
  Chords and scales are lists of note numbers, built from a root given as a name or a number, and
  a scale ends on the octave above its root.
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

  @doc """
  A note number for a number or a note name such as `:c4`, raising `ArgumentError` for an unknown
  name.
  """
  def note(number) when is_number(number), do: number

  def note(name) when is_atom(name) and name not in [nil, true, false] do
    name |> Atom.to_string() |> parse()
  end

  @doc ~s(The note number for text giving a number or a note name, such as "60" or "c4", raising `ArgumentError` for neither.)
  def from_text(text) when is_binary(text) do
    case Integer.parse(text) do
      {number, ""} -> number
      _ -> parse(text)
    end
  end

  @doc """
  The note number for a note name written as text, such as "A2", raising `ArgumentError` for an
  unknown name.
  """
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

  @kinds %{
    "" => :major,
    "m" => :minor,
    "7" => :dom7,
    "m7" => :minor7,
    "maj7" => :major7,
    "dim7" => :dim7,
    "dim" => :dim,
    "aug" => :aug,
    "sus2" => :sus2,
    "sus4" => :sus4,
    "m7b5" => :half_dim7,
    "6" => :major6,
    "m6" => :minor6,
    "7b9" => :dom7_flat9,
    "9" => :dom9
  }

  def chord(name, opts) when is_binary(name) and is_list(opts) do
    from = opts |> Keyword.fetch!(:from) |> note()
    {class, kind} = chord_name(name)
    chord(from + Integer.mod(class - from, 12), kind)
  end

  @doc false
  def chord_name(name) do
    with [_, letter, accidental, kind] <- Regex.run(~r/^([A-G])([#b]?)(.*)$/, name),
         {:ok, kind} <- Map.fetch(@kinds, kind) do
      shift = %{"" => 0, "#" => 1, "b" => -1}[accidental]
      {@letters[String.downcase(letter)] + shift, kind}
    else
      _ ->
        raise ArgumentError,
              "#{name} is no chord; a chord is a capital letter from A to G, # or b, and a kind such as m7, maj7 or dim7"
    end
  end

  @doc """
  The chord written at a beat of a chart, a pattern read a word to every step beats, going round
  past its end.
  """
  def chord_at(chart, step, beat) when is_list(chart) and is_number(beat) do
    if not (is_number(step) and step > 0) do
      step = inspect(step)
      raise ArgumentError, "chord_at takes a step above 0, not step: #{step}"
    end

    length = Enum.sum_by(chart, & &1.steps) * step
    beat = beat - length * Float.floor(beat / length)

    name =
      Enum.reduce_while(chart, 0, fn %{steps: steps} = cell, start ->
        if beat < start + steps * step do
          {:halt, chart_word(cell)}
        else
          {:cont, start + steps * step}
        end
      end)

    chord_name(name)
    name
  end

  defp chart_word(%{tokens: [name]}) when is_binary(name), do: name

  defp chart_word(%{tokens: []}) do
    raise ArgumentError, "a chart takes one chord to a step, not a rest"
  end

  defp chart_word(%{tokens: tokens}) do
    tokens = Enum.join(tokens, " ")
    raise ArgumentError, "a chart takes one chord to a step, not #{tokens}"
  end

  @doc """
  The notes of a scale from a root, ending on the octave above it, over `octaves:` octaves (1 by
  default), or every note of the scale from `from:` up to `to:`; the kind is a name or the steps
  from the root in semitones, from 0 up to below 12.
  """
  def scale(root, kind, opts \\ []) when (is_number(root) or is_atom(root)) and is_list(opts) do
    offsets = offsets!(kind)
    root = note(root)

    case opts |> Keyword.keys() |> Enum.find(&(&1 not in [:octaves, :from, :to])) do
      nil -> :ok
      name -> raise ArgumentError, "scale takes octaves:, or from: and to:, not #{name}:"
    end

    case {Keyword.has_key?(opts, :from), Keyword.has_key?(opts, :to)} do
      {false, false} ->
        octaves = Keyword.get(opts, :octaves, 1)

        notes =
          for octave <- 0..(octaves - 1)//1, offset <- offsets, do: root + 12 * octave + offset

        notes ++ [root + 12 * octaves]

      {true, true} ->
        if Keyword.has_key?(opts, :octaves) do
          raise ArgumentError, "scale takes octaves:, or from: and to:, not both"
        end

        between(root, offsets, note(opts[:from]), note(opts[:to]))

      _ ->
        raise ArgumentError, "scale takes from: and to: together"
    end
  end

  @doc """
  The pitch `number` steps of a scale from its root: 0 is the root, the scale's count of notes the
  root an octave up, and below 0 goes down.
  """
  def degree(root, kind, number) when (is_number(root) or is_atom(root)) and is_integer(number) do
    offsets = offsets!(kind)
    count = length(offsets)
    octave = Integer.floor_div(number, count)
    note(root) + 12 * octave + Enum.at(offsets, Integer.mod(number, count))
  end

  defp between(_root, _offsets, low, high) when low > high do
    raise ArgumentError, "scale takes from: no higher than to:, not from #{low} to #{high}"
  end

  defp between(root, offsets, low, high) do
    lowest = Integer.floor_div(floor(low - root), 12) - 1
    highest = Integer.floor_div(ceil(high - root), 12) + 1

    for octave <- lowest..highest,
        offset <- offsets,
        pitch = root + 12 * octave + offset,
        pitch >= low and pitch <= high,
        do: pitch
  end

  # A scale's notes as their steps from the root within one octave, 0 first.
  defp offsets!(kind) when is_atom(kind) do
    steps = fetch!(@scales, kind, "scale")
    rising = steps |> Enum.drop(-1) |> Enum.scan(&(&1 + &2))
    [0 | rising]
  end

  defp offsets!([0 | _] = steps) do
    rising? = Enum.all?(steps, &is_number/1) and steps == steps |> Enum.uniq() |> Enum.sort()

    if not rising? or List.last(steps) >= 12 do
      steps = inspect(steps)

      raise ArgumentError,
            "a scale's steps rise from 0 to below 12 semitones above the root, not #{steps}"
    end

    steps
  end

  defp offsets!(kind) do
    kind = inspect(kind, charlists: :as_lists)

    raise ArgumentError,
          "a scale is a name, such as :major, or its steps from the root, starting at 0, not #{kind}"
  end

  @doc "The step from each note to the next, from notes given as names or numbers."
  def intervals(notes) when is_list(notes) do
    notes = Enum.map(notes, &note/1)
    Enum.zip_with(notes, Enum.drop(notes, 1), &(&2 - &1))
  end

  @doc """
  The notes reached by taking each step in turn from a start note given as a name or a number.
  """
  def melody(start, steps) when (is_number(start) or is_atom(start)) and is_list(steps) do
    start = note(start)
    [start | Enum.scan(steps, start, &(&1 + &2))]
  end

  @doc """
  The note of a chord, in any octave, closest to a note, the lower on a tie; `except:` leaves out
  one note.
  """
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
    gaps = for tone <- chord, do: Integer.mod(note - tone - 1, 12) + 1
    note - Enum.min(gaps)
  end

  @doc """
  Each note of a chord placed once from `from:` up to `to:`, leaving out the root of a chord of
  more notes than `limit:`.
  """
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

  @doc """
  A scale bent to a chord: each chord tone missing from the scale takes the place of the scale
  note a semitone below it, or a semitone above when there is none below.
  """
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
