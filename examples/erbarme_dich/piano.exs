defmodule ErbarmeDich.Piano do
  @moduledoc """
  Bach's aria "Erbarme dich, mein Gott", BWV 244/39, arranged for mx's piano alone.
  The right hand sings the alto's melody and answers it with the violin's, and plays the violin's
  ritornelli; the left hand keeps the continuo's eighths, detached, with the organ's harmony soft
  under the melodies.
  It is played as a pianist would: the melody ahead of the bass and over it, the sighs leaning on
  their first note, the pulse lingering on each downbeat, slowing into each cadence and breathing
  at the end of each phrase.
  It plays the aria once, as the score asks, through bar 46 and then from the segno at bar 1 to
  the Fine, the fermata on beat 3 of bar 8.
  The notes come from the score beside this song, under CC BY 4.0, as LICENSE.md says: the violin,
  the alto, and the organ's continuo split into its bass and the voices above it.
  """

  @tempo 52

  use Mx.Song, tempo: @tempo

  part :piano,
    synth: :piano,
    defaults: [pedal: 0.5, release: 0.3, amp: 2],
    fx: [reverb: [room: 0.8, damp: 0.5, mix: 0.3]]

  def song do
    part(:piano, at(piano(), beats()))
  end

  defp piano do
    for {beat, note, vel, sustain} <- strokes(), do: {beat, note(note, sustain, vel: vel)}
  end

  # Every stroke of the performance as {beat, note, velocity, sustain}, from its first note.
  defp strokes do
    notes = notes()
    clock = clock(notes)
    voices = Enum.group_by(notes, & &1.voice)
    keys = Enum.group_by(notes, & &1.note)

    notes
    |> Enum.map(&stroke(&1, voices, keys, clock))
    |> Enum.sort()
  end

  # How many beats the performance lasts, with the last chord's fermata and its reverb.
  defp beats do
    strokes()
    |> Enum.map(fn {beat, _note, _vel, sustain} -> beat + sustain end)
    |> Enum.max()
    |> Kernel.+(3)
    |> Float.round(3)
  end

  # The bars in the order they play, the segno taking the ritornello again after bar 46.
  defp order, do: Enum.concat(0..46, 1..8)

  defp last, do: length(order()) - 1

  # The eighth of the performance a bar of it starts on, the pickup being one eighth.
  defp start(0), do: 0
  defp start(index), do: 1 + (index - 1) * 12

  # Each note as a map, its place counted in eighths from the start of the performance; on the
  # way back the music stops at the fermata.
  defp notes do
    notes =
      for {bar, index} <- Enum.with_index(order()),
          {^bar, violin, alto, inner, bass} = List.keyfind(score(), bar, 0),
          shift = if(mean(bass) >= 50, do: -12, else: 0),
          {voice, notes} <- [violin: violin, alto: alto, inner: inner, bass: bass],
          {eighth, note, length} <- notes,
          index < last() or eighth <= 6 do
        %{
          voice: voice,
          at: start(index) + eighth,
          note: if(voice == :bass, do: note + shift, else: note),
          length: length,
          bar: index,
          eighth: eighth,
          fermata: index == last() and eighth + length > 6
        }
      end

    notes = Enum.uniq_by(notes, &{&1.at, &1.note})

    notes
    |> Enum.map(&Map.put(&1, :role, role(&1, notes)))
    |> Enum.reject(&(&1.role == :hidden))
    |> Enum.flat_map(&octave/1)
  end

  # The alto leads while it sings a phrase and the violin answers under it; the violin leads when
  # the alto is silent.
  # The organ's voices at or above a melody's lowest sounding note are left out, so the melodies
  # stand clear over the harmony.
  defp role(%{voice: :alto}, _notes), do: :lead

  defp role(%{voice: :violin, at: at}, notes) do
    if singing?(at, notes), do: :answer, else: :lead
  end

  defp role(%{voice: :inner, at: at, note: note}, notes) do
    lowest =
      notes
      |> Enum.filter(&(&1.voice in [:violin, :alto] and sounding?(&1, at)))
      |> Enum.map(& &1.note)
      |> Enum.min(fn -> 128 end)

    if note >= lowest, do: :hidden, else: :inner
  end

  defp role(%{voice: :bass}, _notes), do: :bass

  # Whether the alto is within a phrase, its breaths of less than two eighths included.
  defp singing?(at, notes) do
    Enum.any?(notes, &(&1.voice == :alto and at >= &1.at - 2 and at < &1.at + &1.length + 2))
  end

  defp sounding?(note, at), do: at >= note.at and at < note.at + note.length

  # The left hand doubles the bass an octave down on each beat of the forte ritornello, and under
  # the last chord.
  defp octave(%{voice: :bass} = note) do
    place = note.bar + note.eighth / 12
    forte = place >= 22.9 and place < 26.5 and rem(trunc(note.eighth), 3) == 0
    final = note.fermata and note.eighth == 6

    if (forte or final) and note.note - 12 >= 28,
      do: [note, %{note | note: note.note - 12, role: :octave}],
      else: [note]
  end

  defp octave(note), do: [note]

  defp stroke(note, voices, keys, clock) do
    start = max(time(clock, note.at) + offset(note, voices) * @tempo / 60, 0.0)

    sustain =
      if note.fermata do
        time(clock, start(last()) + 6) - start + 5
      else
        time(clock, release(note, voices, keys)) - start
      end

    {Float.round(start, 3), note.note, velocity(note, voices), Float.round(max(sustain, 0.05), 3)}
  end

  # When a key is let go, in eighths: the melodies bind each note into the next and lift before a
  # breath, the organ's chords are held, and the bass's eighths are detached, as a continuo
  # player's are.
  # A key struck again lets go first.
  defp release(note, voices, keys) do
    finish = note.at + note.length

    held =
      case note.role do
        role when role in [:lead, :answer] ->
          case after_note(note, voices) do
            %{at: at} when at <= finish -> finish + 0.15
            _ -> note.at + note.length * 0.85
          end

        :inner ->
          note.at + note.length * if(note.length <= 1, do: 0.7, else: 0.95)

        _ ->
          note.at + if(note.length <= 1, do: 0.55, else: note.length * 0.9)
      end

    again =
      keys[note.note]
      |> Enum.filter(&(&1.at > note.at))
      |> Enum.map(&(&1.at - 0.05))
      |> Enum.min(fn -> held end)

    min(held, again)
  end

  # How early or late a key goes down against the beat, in seconds: the melody a little ahead of
  # the bass, the organ's chords rolled up from below, the last chord slowly, and no two strokes
  # exactly together.
  defp offset(note, voices) do
    unsteady = (:erlang.phash2({note.at, note.note}, 1000) / 1000 - 0.5) * 0.012

    together =
      voices
      |> Map.values()
      |> Enum.concat()
      |> Enum.filter(&(&1.at == note.at))
      |> Enum.map(& &1.note)
      |> Enum.sort()

    rank = Enum.find_index(together, &(&1 == note.note))

    cond do
      note.fermata and note.eighth == 6 -> rank * 0.07
      note.role == :lead -> -0.012 + unsteady
      note.role == :answer -> -0.004 + unsteady
      note.role == :inner -> 0.01 + rank * 0.01 + unsteady
      true -> unsteady
    end
  end

  # How hard a key is struck: the loudness of the moment, the lead melody over the answering one,
  # the harmony and the bass behind both, each note shaped by where it falls.
  defp velocity(note, voices) do
    loudness = along(loudness(), note.bar + note.eighth / 12)

    behind =
      if note.role in [:inner, :bass, :octave] and alto_near?(note, voices), do: 0.88, else: 1

    weight =
      case note.role do
        :lead -> 1
        :answer -> 0.8
        :inner -> 0.46
        :bass -> 0.6
        :octave -> 0.42
      end

    vel = loudness * weight * behind * (1 + shape(note, voices))
    Float.round(min(max(vel, 0.04), 0.95), 2)
  end

  defp alto_near?(note, voices), do: singing?(note.at, voices[:alto] || [])

  # A melody's note sounds louder the higher it goes and the longer it lasts, leans on the first
  # note of a sigh and lets its resolution fall away, and softens before a breath.
  defp shape(%{role: role} = note, voices) when role in [:lead, :answer] do
    previous = before_note(note, voices)
    next = after_note(note, voices)

    leans = if sigh?(note, next), do: 0.07, else: 0
    falls = if sigh?(previous, note), do: -0.07, else: 0
    breath = if next == nil or next.at > note.at + note.length, do: -0.06, else: 0
    length = min(max(0.07 * :math.log2(note.length), -0.12), 0.1)

    (note.note - 72) * 0.008 + length + stress(note.eighth) * 0.025 + leans + falls + breath
  end

  # The bass's eighths lean on each beat of the bar, more where the harmony moves.
  defp shape(%{role: :bass} = note, voices) do
    moves =
      case before_note(note, voices) do
        %{note: previous} when previous != note.note -> 0.05
        _ -> 0
      end

    if rem(trunc(note.eighth), 3) == 0 and note.eighth == trunc(note.eighth),
      do: moves,
      else: moves - 0.15
  end

  defp shape(note, _voices), do: stress(note.eighth) * 0.02

  # How strong a place in the 12/8 bar is: its downbeat, its other beats, its eighths, and
  # whatever falls between them.
  defp stress(eighth) when eighth == 0, do: 2
  defp stress(eighth) when eighth == trunc(eighth) and rem(trunc(eighth), 3) == 0, do: 1.5
  defp stress(eighth) when eighth == trunc(eighth), do: 0.5
  defp stress(_eighth), do: 0

  # A sigh is a stronger note falling a step to the note bound to it.
  defp sigh?(%{} = first, %{} = second) do
    second.at == first.at + first.length and (first.note - second.note) in [1, 2] and
      stress(first.eighth) > stress(second.eighth)
  end

  defp sigh?(_first, _second), do: false

  defp before_note(note, voices) do
    voices[note.voice]
    |> Enum.filter(&(&1.at < note.at))
    |> Enum.max_by(& &1.at, fn -> nil end)
  end

  defp after_note(note, voices) do
    voices[note.voice]
    |> Enum.filter(&(&1.at > note.at))
    |> Enum.min_by(& &1.at, fn -> nil end)
  end

  # The beat each eighth of the performance starts on, as a tuple, the eighths stretched by the
  # rubato.
  defp clock(notes) do
    count = notes |> Enum.map(& &1.at) |> Enum.max() |> trunc() |> Kernel.+(13)
    cadences = cadences(notes)

    0..count
    |> Enum.map(&stretch(&1, cadences))
    |> Enum.scan(0, &(&1 * 0.5 + &2))
    |> then(&List.to_tuple([0 | &1]))
  end

  defp time(clock, eighth) do
    whole = trunc(eighth)
    from = elem(clock, whole)
    from + (elem(clock, whole + 1) - from) * (eighth - whole)
  end

  # How long an eighth lasts against the tempo: the pace of the phrase, each bar lingering on its
  # downbeat and a little on its other beats, and the music slowing into each cadence and resting
  # on its arrival.
  defp stretch(eighth, cadences) do
    index = if eighth == 0, do: 0, else: div(eighth - 1, 12) + 1
    place = eighth - start(index)

    linger =
      cond do
        place == 0 -> 0.06
        rem(place, 3) == 0 -> 0.02
        true -> 0
      end

    slowing =
      cadences
      |> Enum.map(fn {arrival, weight} ->
        arrival = trunc(arrival)

        cond do
          eighth == arrival -> weight * 0.8
          eighth in (arrival - 4)..(arrival - 1)//1 -> weight * ((eighth - arrival + 5) / 4) ** 2
          true -> 0
        end
      end)
      |> Enum.sum()

    along(pace(), index + place / 12) + linger + slowing
  end

  # How slowly the music moves against the tempo, as {bar, pace}, a bar counted through the
  # performance: each entry settles, the phrases move through their middles and broaden into
  # their ends, the forte ritornello presses on, and the second part pushes towards bar 41.
  defp pace do
    [
      {0, 1.04},
      {2, 1.0},
      {3.5, 0.98},
      {4.5, 1.03},
      {5, 0.99},
      {7, 0.97},
      {8.5, 1.02},
      {9, 1.03},
      {11, 0.99},
      {13, 1.0},
      {15, 0.98},
      {17, 1.0},
      {19, 0.98},
      {22, 1.02},
      {23, 0.97},
      {26, 1.0},
      {27, 1.02},
      {30, 0.98},
      {34, 0.99},
      {38, 1.0},
      {41, 0.97},
      {42, 1.03},
      {44, 0.99},
      {46.5, 1.04},
      {47, 1.0},
      {50, 0.99},
      {52, 1.02},
      {54, 1.1}
    ]
  end

  # Where the music comes to rest, as {eighth, weight}: the end of each of the alto's phrases,
  # more for a longer breath after it, and the ritornello's cadences, the last one the most.
  defp cadences(notes) do
    alto = notes |> Enum.filter(&(&1.voice == :alto)) |> Enum.sort_by(& &1.at)

    phrases =
      alto
      |> Enum.chunk_every(2, 1)
      |> Enum.flat_map(fn
        [note, next] ->
          gap = next.at - note.at - note.length
          if gap >= 1.5, do: [{note.at, min(0.3, 0.075 * gap)}], else: []

        [note] ->
          [{note.at, 0.3}]
      end)

    ritornello =
      for {index, eighth, weight} <- [{4, 6, 0.18}, {8, 6, 0.33}, {26, 6, 0.3}, {last(), 6, 1.2}],
          do: {start(index) + eighth, weight}

    phrases ++ ritornello
  end

  # How loud the moment is, as {bar, loudness}, a bar counted through the performance, the return
  # of the ritornello being bars 47 to 54.
  # The ritornello rises to its sequence in bars 5 to 7, the alto sings over the organ's
  # pianissimo, the violin's ritornello in bars 23 to 26 is forte as marked, the second part grows
  # towards bar 41, and the ritornello comes back softer and fades into the fermata.
  defp loudness do
    [
      {0, 0.4},
      {2.5, 0.48},
      {3.5, 0.5},
      {4.5, 0.42},
      {5, 0.45},
      {7, 0.55},
      {8.5, 0.4},
      {9, 0.44},
      {12, 0.48},
      {15, 0.45},
      {18, 0.52},
      {21, 0.47},
      {22.9, 0.44},
      {22.9, 0.62},
      {25, 0.66},
      {26.5, 0.58},
      {26.75, 0.44},
      {30, 0.48},
      {33, 0.54},
      {36, 0.5},
      {39, 0.53},
      {41.5, 0.6},
      {43, 0.56},
      {45, 0.5},
      {46.5, 0.4},
      {47, 0.36},
      {49.5, 0.42},
      {51, 0.36},
      {53, 0.4},
      {54.5, 0.3}
    ]
  end

  # The value at a place of a curve given as keys, straight between them.
  defp along(keys, at) do
    span =
      keys
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.find(fn [{from, _}, {to, _}] -> at >= from and at < to end)

    case span do
      [{from, a}, {to, b}] -> a + (b - a) * (at - from) / (to - from)
      nil -> keys |> List.last() |> elem(1)
    end
  end

  defp mean([]), do: 0
  defp mean(notes), do: Enum.sum(Enum.map(notes, &elem(&1, 1))) / length(notes)

  # Each bar as {number, violin, alto, organ, bass}, a voice being notes of {eighth, note,
  # eighths held}, bar 0 being the eighth before the first bar.
  defp score do
    [
      {0, [{0, 66, 1}], [], [], [{0, 47, 1}]},
      {1,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.5},
         {2, 71, 1},
         {3, 71, 1.5},
         {4.5, 70, 0.5},
         {5, 71, 1},
         {6, 71, 5},
         {11, 71, 1}
       ], [],
       [{0, 62, 9}, {0, 66, 6}, {0, 71, 9}, {6, 67, 3}, {9, 66, 3}, {9, 69, 3}, {9, 75, 3}],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 55, 1},
         {7, 55, 1},
         {8, 55, 1},
         {9, 54, 1},
         {10, 54, 1},
         {11, 54, 1}
       ]},
      {2,
       [
         {0, 79, 1.5},
         {1.5, 78, 0.25},
         {1.75, 79, 0.25},
         {2, 81, 2.5},
         {4.5, 79, 0.5},
         {5, 78, 1},
         {6, 76, 4.5},
         {10.5, 79, 0.5},
         {11, 76, 1}
       ], [],
       [
         {0, 59, 3},
         {0, 71, 6},
         {0, 76, 3},
         {3, 57, 3},
         {3, 75, 3},
         {6, 55, 3},
         {6, 71, 6},
         {6, 76, 6},
         {9, 67, 3}
       ],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 54, 1},
         {4, 54, 1},
         {5, 54, 1},
         {6, 55, 1},
         {7, 52, 1},
         {8, 55, 1},
         {9, 59, 1},
         {10, 55, 1},
         {11, 59, 1}
       ]},
      {3,
       [
         {0, 72, 1.5},
         {1.5, 79, 0.5},
         {2, 76, 1},
         {3, 71, 1.5},
         {4.5, 79, 0.5},
         {5, 76, 1},
         {6, 70, 1.5},
         {7.5, 76, 0.25},
         {7.75, 78, 0.25},
         {8, 79, 2.5},
         {10.5, 78, 0.5},
         {11, 76, 1}
       ], [],
       [{0, 72, 3}, {0, 76, 12}, {0, 79, 9}, {3, 71, 3}, {6, 70, 3}, {9, 73, 3}, {9, 73, 3}],
       [
         {0, 64, 1},
         {1, 64, 1},
         {2, 64, 1},
         {3, 62, 1},
         {4, 62, 1},
         {5, 62, 1},
         {6, 61, 1},
         {7, 61, 1},
         {8, 61, 1},
         {9, 58, 1},
         {10, 58, 1},
         {11, 58, 1}
       ]},
      {4,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 2.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 70, 3},
         {9, 70, 1.5},
         {10.5, 66, 0.5},
         {11, 70, 0.5},
         {11.5, 73, 0.5}
       ], [],
       [
         {0, 66, 3},
         {0, 74, 3},
         {0, 74, 3},
         {3, 67, 3},
         {3, 71, 3},
         {3, 76, 3},
         {6, 61, 3},
         {6, 70, 5},
         {6, 78, 5},
         {9, 73, 2}
       ],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 55, 1},
         {4, 55, 1},
         {5, 55, 1},
         {6, 54, 1},
         {7, 49, 1},
         {8, 52, 1},
         {9, 52, 1},
         {10, 46, 1},
         {11, 49, 1}
       ]},
      {5,
       [
         {0, 76, 0.25},
         {0.25, 74, 0.25},
         {0.5, 73, 0.5},
         {1, 71, 1},
         {2, 70, 0.5},
         {2.5, 71, 0.5},
         {3, 73, 0.25},
         {3.25, 71, 0.25},
         {3.5, 70, 0.5},
         {4, 67, 1},
         {5, 66, 0.5},
         {5.5, 67, 0.5},
         {6, 67, 0.25},
         {6.25, 66, 0.25},
         {6.5, 64, 0.5},
         {7, 70, 1.5},
         {8.5, 67, 0.25},
         {8.75, 66, 0.25},
         {9, 67, 0.25},
         {9.25, 66, 0.25},
         {9.5, 64, 0.5},
         {10, 73, 1.5},
         {11.5, 66, 0.25},
         {11.75, 64, 0.25}
       ], [],
       [
         {0, 61, 1},
         {0, 66, 1},
         {0, 70, 1},
         {1, 62, 1},
         {1, 68, 1},
         {1, 71, 1},
         {2, 64, 1},
         {2, 70, 1},
         {2, 73, 1},
         {3, 54, 1},
         {3, 70, 1},
         {3, 73, 1},
         {4, 54, 1},
         {4, 71, 1},
         {4, 74, 1},
         {5, 54, 1},
         {5, 73, 1},
         {5, 76, 1},
         {6, 70, 3},
         {6, 73, 3},
         {6, 76, 5},
         {9, 70, 2},
         {9, 73, 2}
       ], [{0, 42, 2}, {6, 42, 1}, {7, 42, 1}, {8, 42, 1}, {9, 42, 1}, {10, 42, 1}, {11, 42, 1}]},
      {6,
       [
         {0, 66, 0.25},
         {0.25, 64, 0.25},
         {0.5, 63, 0.5},
         {1, 60, 1},
         {2, 59, 0.5},
         {2.5, 69, 0.25},
         {2.75, 67, 0.25},
         {3, 69, 0.25},
         {3.25, 67, 0.25},
         {3.5, 66, 0.5},
         {4, 64, 1},
         {5, 63, 0.5},
         {5.5, 72, 0.25},
         {5.75, 71, 0.25},
         {6, 72, 0.25},
         {6.25, 71, 0.25},
         {6.5, 69, 0.5},
         {7, 67, 1},
         {8, 66, 0.5},
         {8.5, 78, 0.25},
         {8.75, 76, 0.25},
         {9, 78, 0.25},
         {9.25, 76, 0.25},
         {9.5, 75, 0.5},
         {10, 72, 1},
         {11, 71, 0.5},
         {11.5, 78, 0.5}
       ], [],
       [
         {0, 57, 1},
         {0, 63, 1},
         {0, 66, 1},
         {1, 55, 1},
         {1, 64, 1},
         {1, 67, 1},
         {2, 54, 1},
         {2, 66, 1},
         {2, 69, 1},
         {3, 59, 1},
         {3, 63, 1},
         {3, 66, 1},
         {4, 59, 1},
         {4, 64, 1},
         {4, 67, 1},
         {5, 59, 1},
         {5, 66, 1},
         {5, 69, 1},
         {6, 63, 5},
         {6, 69, 5}
       ], [{0, 47, 2}, {6, 47, 1}, {7, 47, 1}, {8, 47, 1}, {9, 47, 1}, {10, 47, 1}, {11, 47, 1}]},
      {7,
       [
         {0, 79, 0.25},
         {0.25, 81, 0.25},
         {0.5, 83, 1},
         {1.5, 81, 0.25},
         {1.75, 79, 0.25},
         {2, 81, 0.25},
         {2.25, 79, 0.25},
         {2.5, 78, 0.5},
         {3, 76, 0.25},
         {3.25, 78, 0.25},
         {3.5, 79, 1},
         {4.5, 78, 0.25},
         {4.75, 76, 0.25},
         {5, 78, 0.25},
         {5.25, 76, 0.25},
         {5.5, 74, 0.5},
         {6, 72, 0.25},
         {6.25, 74, 0.25},
         {6.5, 76, 1},
         {7.5, 74, 0.25},
         {7.75, 72, 0.25},
         {8, 74, 0.25},
         {8.25, 72, 0.25},
         {8.5, 71, 0.5},
         {9, 70, 0.25},
         {9.25, 71, 0.25},
         {9.5, 73, 1},
         {10.5, 71, 0.25},
         {10.75, 70, 0.25},
         {11, 71, 0.25},
         {11.25, 70, 0.25},
         {11.5, 68, 0.5}
       ], [],
       [
         {0, 59, 3},
         {0, 64, 3},
         {0, 67, 3},
         {3, 64, 3},
         {3, 67, 3},
         {3, 71, 3},
         {6, 67, 3},
         {6, 72, 3},
         {6, 76, 3},
         {9, 73, 1},
         {9, 76, 1},
         {9, 79, 1},
         {10, 70, 2},
         {10, 73, 2},
         {10, 78, 2}
       ],
       [
         {0, 40, 1},
         {1, 40, 1},
         {2, 40, 1},
         {3, 40, 1},
         {4, 40, 1},
         {5, 40, 1},
         {6, 40, 1},
         {7, 40, 1},
         {8, 40, 1},
         {9, 40, 1},
         {10, 40, 1},
         {11, 52, 1}
       ]},
      {8,
       [
         {0, 66, 1.5},
         {1.5, 68, 0.25},
         {1.75, 70, 0.25},
         {2, 71, 0.25},
         {2.25, 73, 0.25},
         {2.5, 74, 0.25},
         {2.75, 73, 0.25},
         {3, 76, 1},
         {4, 74, 1},
         {5, 73, 1},
         {6, 71, 5}
       ], [{11, 66, 1}],
       [
         {0, 71, 1},
         {0, 74, 1},
         {0, 78, 1},
         {1, 70, 1},
         {1, 70, 1},
         {1, 76, 1},
         {2, 66, 1},
         {2, 71, 1},
         {2, 74, 1},
         {3, 61, 1},
         {3, 71, 1},
         {3, 76, 1},
         {4, 62, 1},
         {4, 71, 1},
         {4, 74, 1},
         {5, 64, 1},
         {5, 70, 1},
         {5, 73, 1},
         {6, 62, 1},
         {6, 66, 1},
         {6, 71, 1},
         {7, 64, 1},
         {7, 70, 1},
         {7, 73, 1},
         {8, 66, 1},
         {8, 71, 1},
         {8, 74, 1},
         {9, 64, 1},
         {9, 70, 1},
         {9, 73, 1},
         {10, 66, 1},
         {10, 71, 1},
         {10, 74, 1},
         {11, 70, 1},
         {11, 73, 1},
         {11, 76, 1}
       ],
       [
         {0, 50, 1},
         {1, 49, 1},
         {2, 47, 1},
         {3, 54, 1},
         {4, 54, 1},
         {5, 42, 1},
         {6, 47, 5},
         {11, 47, 1}
       ]},
      {9, [{11, 71, 1}],
       [{0, 74, 1.5}, {1.5, 73, 0.5}, {2, 71, 2.5}, {4.5, 70, 0.5}, {5, 71, 1}, {6, 71, 6}],
       [
         {0, 66, 6},
         {0, 71, 6},
         {0, 74, 9},
         {6, 67, 3},
         {6, 71, 3},
         {9, 69, 3},
         {9, 69, 3},
         {9, 75, 3}
       ],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 55, 1},
         {7, 55, 1},
         {8, 55, 1},
         {9, 54, 1},
         {10, 54, 1},
         {11, 54, 1}
       ]},
      {10,
       [
         {0, 79, 1.5},
         {1.5, 78, 0.25},
         {1.75, 79, 0.25},
         {2, 81, 2.5},
         {4.5, 79, 0.5},
         {5, 78, 1},
         {6, 76, 3},
         {9, 76, 1.5},
         {10.5, 79, 0.5},
         {11, 76, 1}
       ],
       [
         {0, 71, 2},
         {2, 64, 1},
         {3, 64, 1},
         {4, 63, 1},
         {5, 69, 1},
         {6, 67, 2},
         {8, 66, 1},
         {9, 67, 2},
         {11, 71, 1}
       ],
       [
         {0, 67, 3},
         {0, 71, 3},
         {0, 76, 3},
         {3, 66, 3},
         {3, 69, 3},
         {3, 72, 3},
         {6, 67, 6},
         {6, 71, 3},
         {6, 71, 6},
         {9, 76, 3}
       ],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 52, 1},
         {4, 52, 1},
         {5, 52, 1},
         {6, 52, 1},
         {7, 52, 1},
         {8, 52, 1},
         {9, 52, 1},
         {10, 52, 1},
         {11, 52, 1}
       ]},
      {11,
       [
         {0, 72, 1.5},
         {1.5, 79, 0.5},
         {2, 76, 1},
         {3, 71, 1.5},
         {4.5, 79, 0.5},
         {5, 76, 1},
         {6, 70, 1.5},
         {7.5, 76, 0.25},
         {7.75, 78, 0.25},
         {8, 79, 2.5},
         {10.5, 78, 0.5},
         {11, 76, 1}
       ], [{0, 72, 2}, {2, 71, 1}, {3, 71, 2}, {5, 70, 1}, {6, 70, 2}, {8, 71, 1}, {9, 73, 4.5}],
       [
         {0, 64, 6},
         {0, 76, 6},
         {0, 79, 9},
         {6, 52, 3},
         {6, 76, 3},
         {9, 58, 3},
         {9, 73, 3},
         {9, 76, 3}
       ],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 50, 1},
         {4, 50, 1},
         {5, 50, 1},
         {6, 49, 1},
         {7, 49, 1},
         {8, 49, 1},
         {9, 46, 1},
         {10, 46, 1},
         {11, 46, 1}
       ]},
      {12,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 2.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 70, 5}
       ],
       [
         {1.5, 70, 0.5},
         {2, 71, 1},
         {3, 73, 0.5},
         {3.5, 74, 0.5},
         {4, 76, 1},
         {5, 73, 1},
         {6, 70, 2},
         {8, 68, 1},
         {9, 66, 2},
         {11, 64, 1}
       ],
       [
         {0, 66, 3},
         {0, 74, 3},
         {0, 74, 3},
         {3, 67, 3},
         {3, 71, 3},
         {3, 76, 3},
         {6, 61, 1},
         {6, 70, 1},
         {6, 78, 3},
         {7, 62, 1},
         {7, 71, 1},
         {8, 64, 1},
         {8, 73, 1},
         {9, 58, 1},
         {9, 61, 1},
         {9, 78, 2},
         {10, 59, 1},
         {10, 62, 1},
         {11, 61, 1},
         {11, 64, 1}
       ], [{0, 47, 1}, {1, 47, 1}, {2, 47, 1}, {3, 43, 1}, {4, 43, 1}, {5, 43, 1}, {6, 54, 2}]},
      {13, [{7.5, 76, 0.5}, {8, 71, 1}, {9, 67, 2}],
       [
         {0, 63, 1},
         {1, 66, 0.5},
         {1.5, 69, 0.5},
         {2, 72, 2.5},
         {4.5, 71, 0.5},
         {5, 69, 1},
         {6, 67, 5},
         {11, 66, 1}
       ],
       [
         {0, 59, 1},
         {0, 66, 1},
         {0, 72, 1.5},
         {1, 59, 1},
         {1, 66, 1},
         {1.5, 71, 0.5},
         {2, 59, 1},
         {2, 66, 1},
         {2, 69, 1},
         {3, 59, 1},
         {3, 66, 1},
         {3, 75, 1.5},
         {4, 59, 1},
         {4, 66, 1},
         {4.5, 76, 0.5},
         {5, 59, 1},
         {5, 66, 1},
         {5, 78, 1},
         {6, 59, 1},
         {6, 67, 1},
         {6, 78, 1},
         {7, 59, 1},
         {7, 67, 1},
         {7, 76, 2},
         {8, 57, 1},
         {8, 66, 1},
         {9, 59, 1},
         {9, 67, 1},
         {9, 76, 2},
         {10, 61, 1},
         {10, 70, 1},
         {11, 62, 1},
         {11, 71, 1},
         {11, 71, 1}
       ], [{0, 47, 2}, {6, 52, 2}]},
      {14, [{7.5, 78, 0.5}, {8, 73, 1}, {9, 69, 2}, {11, 73, 1}],
       [
         {0, 65, 1},
         {1, 68, 0.5},
         {1.5, 71, 0.5},
         {2, 74, 2.5},
         {4.5, 73, 0.5},
         {5, 71, 1},
         {6, 69, 2},
         {8, 68, 1},
         {9, 69, 1.5},
         {10.5, 73, 0.5},
         {11, 71, 1}
       ],
       [
         {0, 61, 1},
         {0, 68, 1},
         {0, 74, 1.5},
         {1, 61, 1},
         {1, 68, 1},
         {1.5, 73, 0.5},
         {2, 61, 1},
         {2, 68, 1},
         {2, 71, 1},
         {3, 61, 1},
         {3, 68, 1},
         {3, 77, 1.5},
         {4, 61, 1},
         {4, 68, 1},
         {4.5, 78, 0.5},
         {5, 61, 1},
         {5, 68, 1},
         {5, 80, 1},
         {6, 61, 1},
         {6, 69, 1},
         {6, 80, 1},
         {7, 57, 1},
         {7, 66, 1},
         {7, 78, 2},
         {8, 59, 1},
         {8, 65, 1},
         {9, 61, 1},
         {9, 66, 1},
         {9, 78, 2},
         {10, 69, 1},
         {10, 78, 1},
         {11, 68, 1},
         {11, 77, 1}
       ], [{0, 49, 2}, {6, 54, 2}]},
      {15,
       [
         {0, 81, 1.5},
         {1.5, 80, 0.5},
         {2, 78, 1},
         {3, 78, 1.5},
         {4.5, 77, 0.5},
         {5, 78, 1},
         {6, 78, 8}
       ], [{0, 73, 7.5}, {7.5, 71, 0.5}, {8, 70, 2.5}, {10.5, 71, 0.5}, {11, 73, 1}],
       [
         {0, 69, 7},
         {0, 73, 6},
         {0, 78, 6},
         {6, 74, 3},
         {6, 78, 3},
         {7, 68, 1},
         {8, 66, 1},
         {9, 64, 1},
         {9, 70, 3},
         {9, 76, 3},
         {10, 62, 1},
         {11, 61, 1}
       ],
       [
         {0, 54, 1},
         {1, 54, 1},
         {2, 54, 1},
         {3, 52, 1},
         {4, 52, 1},
         {5, 52, 1},
         {6, 50, 1},
         {7, 50, 1},
         {8, 50, 1},
         {9, 49, 1},
         {10, 49, 1},
         {11, 49, 1}
       ]},
      {16,
       [
         {2, 71, 1},
         {3, 71, 1},
         {4, 70, 1},
         {5, 76, 2},
         {7, 74, 0.5},
         {7.5, 78, 0.5},
         {8, 73, 2},
         {10, 71, 0.5},
         {10.5, 74, 0.5},
         {11, 69, 1}
       ],
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 1},
         {3, 76, 1.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 71, 5},
         {11, 69, 1}
       ],
       [
         {0, 66, 9},
         {0, 71, 3},
         {0, 74, 3},
         {3, 73, 3},
         {3, 76, 2},
         {5, 70, 1},
         {6, 71, 3},
         {6, 71, 6},
         {9, 62, 3},
         {9, 66, 3}
       ],
       [
         {0, 47, 1},
         {1, 47, 1},
         {2, 47, 1},
         {3, 49, 1},
         {4, 49, 1},
         {5, 49, 1},
         {6, 50, 1},
         {7, 47, 1},
         {8, 50, 1},
         {9, 54, 1},
         {10, 50, 1},
         {11, 54, 1}
       ]},
      {17,
       [
         {0, 67, 1.5},
         {1.5, 74, 0.5},
         {2, 71, 1},
         {3, 66, 1.5},
         {4.5, 74, 0.5},
         {5, 71, 1},
         {6, 65, 1.5},
         {7.5, 71, 0.25},
         {7.75, 73, 0.25},
         {8, 74, 2.5},
         {10.5, 73, 0.5},
         {11, 71, 1}
       ],
       [
         {0, 67, 2},
         {2, 66, 1},
         {3, 66, 2},
         {5, 65, 1},
         {6, 65, 1.5},
         {7.5, 71, 0.25},
         {7.75, 73, 0.25},
         {8, 74, 2.5},
         {10.5, 73, 0.5},
         {11, 71, 1}
       ],
       [
         {0, 71, 9},
         {0, 74, 6},
         {3, 66, 3},
         {6, 68, 3},
         {6, 74, 3},
         {9, 68, 3},
         {9, 68, 3},
         {9, 71, 3}
       ],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 56, 1},
         {7, 56, 1},
         {8, 56, 1},
         {9, 53, 1},
         {10, 53, 1},
         {11, 53, 1}
       ]},
      {18,
       [
         {0, 69, 1.5},
         {1.5, 68, 0.25},
         {1.75, 69, 0.25},
         {2, 71, 2.5},
         {4.5, 69, 0.5},
         {5, 68, 1},
         {6, 65, 3.5},
         {9.5, 66, 0.5},
         {10, 68, 0.5},
         {10.5, 73, 0.5},
         {11, 77, 0.5},
         {11.5, 80, 0.5}
       ],
       [
         {0, 69, 1.5},
         {1.5, 68, 0.5},
         {2, 71, 2.5},
         {4.5, 69, 0.5},
         {5, 68, 1},
         {6, 65, 2},
         {8, 63, 1},
         {9, 61, 2}
       ],
       [
         {0, 61, 3},
         {0, 69, 3},
         {0, 69, 3},
         {3, 62, 3},
         {3, 66, 3},
         {3, 71, 3},
         {6, 56, 5},
         {6, 68, 5},
         {6, 73, 5}
       ],
       [
         {0, 54, 1},
         {1, 54, 1},
         {2, 54, 1},
         {3, 50, 1},
         {4, 50, 1},
         {5, 50, 1},
         {6, 49, 1},
         {7, 44, 1},
         {8, 47, 1},
         {9, 47, 1},
         {10, 41, 1},
         {11, 44, 1}
       ]},
      {19,
       [
         {0, 83, 0.25},
         {0.25, 81, 0.25},
         {0.5, 80, 0.5},
         {1, 78, 1},
         {2, 77, 0.75},
         {2.75, 78, 0.25},
         {3, 80, 0.25},
         {3.25, 78, 0.25},
         {3.5, 77, 0.5},
         {4, 74, 1},
         {5, 73, 0.75},
         {5.75, 74, 0.25},
         {6, 77, 5}
       ],
       [
         {4.5, 61, 0.5},
         {5, 65, 0.5},
         {5.5, 68, 0.5},
         {6, 71, 1.5},
         {7.5, 73, 0.5},
         {8, 74, 2.5},
         {10.5, 73, 0.5},
         {11, 71, 1}
       ],
       [
         {0, 68, 1},
         {0, 73, 1},
         {0, 77, 1},
         {1, 69, 1},
         {1, 75, 1},
         {1, 78, 1},
         {2, 71, 1},
         {2, 77, 1},
         {2, 80, 1},
         {3, 61, 1},
         {3, 77, 1},
         {3, 80, 1},
         {4, 61, 1},
         {4, 78, 1},
         {4, 81, 1},
         {5, 61, 1},
         {5, 80, 1},
         {5, 83, 1},
         {6, 61, 5},
         {6, 68, 5},
         {6, 77, 3},
         {9, 77, 2}
       ], [{0, 37, 2}, {6, 49, 1}, {7, 49, 1}, {8, 49, 1}, {9, 49, 1}, {10, 49, 1}, {11, 49, 1}]},
      {20,
       [
         {0, 76, 0.25},
         {0.25, 74, 0.25},
         {0.5, 73, 0.5},
         {1, 71, 1},
         {2, 70, 0.75},
         {2.75, 71, 0.25},
         {3, 73, 0.25},
         {3.25, 71, 0.25},
         {3.5, 70, 0.5},
         {4, 67, 1},
         {5, 66, 0.75},
         {5.75, 67, 0.25},
         {6, 70, 5}
       ],
       [
         {0, 70, 2},
         {2, 73, 1},
         {3, 76, 1.5},
         {4.5, 73, 0.5},
         {5, 70, 0.5},
         {5.5, 71, 0.5},
         {6, 64, 1.5},
         {7.5, 66, 0.5},
         {8, 67, 2.5},
         {10.5, 66, 0.5},
         {11, 64, 1}
       ],
       [
         {0, 66, 1},
         {0, 70, 1},
         {0, 73, 1},
         {1, 66, 1},
         {1, 71, 1},
         {1, 74, 1},
         {2, 66, 1},
         {2, 73, 1},
         {2, 76, 1},
         {3, 66, 1},
         {3, 70, 1},
         {3, 73, 1},
         {4, 66, 1},
         {4, 71, 1},
         {4, 74, 1},
         {5, 66, 1},
         {5, 73, 1},
         {5, 76, 1},
         {6, 61, 5},
         {6, 66, 5},
         {6, 70, 5}
       ], [{0, 42, 2}, {6, 42, 1}, {7, 42, 1}, {8, 42, 1}, {9, 42, 1}, {10, 42, 1}, {11, 42, 1}]},
      {21,
       [
         {0, 74, 0.25},
         {0.25, 76, 0.25},
         {0.5, 78, 1},
         {1.5, 76, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 0.25},
         {2.25, 74, 0.25},
         {2.5, 73, 0.5},
         {3, 71, 0.25},
         {3.25, 73, 0.25},
         {3.5, 74, 1},
         {4.5, 73, 0.25},
         {4.75, 71, 0.25},
         {5, 73, 0.25},
         {5.25, 71, 0.25},
         {5.5, 70, 0.5},
         {6, 67, 0.25},
         {6.25, 69, 0.25},
         {6.5, 71, 1},
         {7.5, 69, 0.25},
         {7.75, 67, 0.25},
         {8, 69, 0.25},
         {8.25, 67, 0.25},
         {8.5, 66, 0.5},
         {9, 65, 0.25},
         {9.25, 66, 0.25},
         {9.5, 68, 1},
         {10.5, 66, 0.25},
         {10.75, 65, 0.25},
         {11, 66, 0.25},
         {11.25, 65, 0.25},
         {11.5, 63, 0.5}
       ],
       [
         {0, 62, 1},
         {1, 64, 1},
         {2, 66, 2},
         {4, 68, 1},
         {5, 70, 1},
         {6, 71, 1},
         {7, 73, 1},
         {8, 74, 2},
         {10, 73, 0.5},
         {10.5, 71, 0.5},
         {11, 69, 0.5},
         {11.5, 68, 0.5}
       ],
       [
         {0, 54, 3},
         {0, 59, 3},
         {0, 62, 3},
         {3, 59, 3},
         {3, 62, 3},
         {3, 66, 3},
         {6, 62, 3},
         {6, 67, 3},
         {6, 71, 3},
         {9, 56, 1},
         {9, 71, 1},
         {9, 74, 1},
         {10, 65, 2},
         {10, 68, 2},
         {10, 73, 2}
       ],
       [
         {0, 47, 1},
         {1, 47, 1},
         {2, 47, 1},
         {3, 47, 1},
         {4, 47, 1},
         {5, 47, 1},
         {6, 47, 1},
         {7, 47, 1},
         {8, 47, 1},
         {9, 47, 1},
         {10, 47, 1},
         {11, 47, 1}
       ]},
      {22, [{0, 61, 1}, {11, 73, 1}],
       [
         {0, 73, 1},
         {1, 71, 1},
         {2, 69, 1},
         {3, 71, 1},
         {4, 69, 1},
         {5, 68, 1},
         {6, 66, 3},
         {9, 66, 2}
       ],
       [
         {0, 66, 2},
         {0, 69, 2},
         {0, 73, 2},
         {4, 61, 4},
         {4, 66, 1},
         {4, 69, 1},
         {5, 65, 1},
         {5, 71, 1},
         {6, 66, 3},
         {6, 69, 3}
       ],
       [
         {0, 45, 1},
         {1, 44, 1},
         {2, 42, 1},
         {3, 49, 1},
         {4, 49, 1},
         {5, 49, 1},
         {6, 54, 1},
         {7, 42, 1},
         {8, 45, 1},
         {9, 49, 1},
         {10, 45, 1},
         {11, 49, 1}
       ]},
      {23,
       [
         {0, 81, 1.5},
         {1.5, 80, 0.5},
         {2, 78, 1},
         {3, 78, 1.5},
         {4.5, 77, 0.5},
         {5, 78, 1},
         {6, 78, 5},
         {11, 78, 1}
       ], [],
       [
         {0, 66, 8},
         {0, 69, 8},
         {0, 73, 8},
         {8, 59, 1},
         {8, 71, 1},
         {8, 71, 1},
         {9, 61, 3},
         {9, 71, 2},
         {9, 76, 1},
         {10, 74, 1},
         {11, 70, 1},
         {11, 73, 1}
       ],
       [
         {0, 54, 1},
         {1, 54, 1},
         {2, 54, 1},
         {3, 52, 1},
         {4, 52, 1},
         {5, 52, 1},
         {6, 50, 1},
         {7, 50, 1},
         {8, 50, 1},
         {9, 49, 1},
         {10, 49, 1},
         {11, 49, 1}
       ]},
      {24,
       [
         {0, 86, 1.5},
         {1.5, 85, 0.25},
         {1.75, 86, 0.25},
         {2, 88, 1},
         {3, 88, 1.5},
         {4.5, 86, 0.5},
         {5, 85, 1},
         {6, 83, 4.5},
         {10.5, 86, 0.5},
         {11, 83, 1}
       ], [],
       [
         {0, 66, 3},
         {0, 71, 3},
         {0, 74, 3},
         {3, 64, 3},
         {3, 67, 5},
         {3, 70, 3},
         {6, 62, 6},
         {6, 71, 6},
         {8, 66, 1},
         {9, 71, 2},
         {11, 74, 1}
       ],
       [
         {0, 47, 1},
         {1, 47, 1},
         {2, 47, 1},
         {3, 49, 1},
         {4, 49, 1},
         {5, 49, 1},
         {6, 50, 1},
         {7, 47, 1},
         {8, 50, 1},
         {9, 54, 1},
         {10, 50, 1},
         {11, 54, 1}
       ]},
      {25,
       [
         {0, 79, 1.5},
         {1.5, 86, 0.5},
         {2, 83, 1},
         {3, 78, 1.5},
         {4.5, 86, 0.5},
         {5, 83, 1},
         {6, 77, 1.5},
         {7.5, 80, 0.25},
         {7.75, 81, 0.25},
         {8, 83, 1},
         {9, 74, 1.5},
         {10.5, 73, 0.5},
         {11, 71, 1}
       ], [],
       [{0, 62, 9}, {0, 71, 12}, {0, 79, 3}, {3, 78, 3}, {6, 77, 3}, {9, 56, 3}, {9, 80, 4}],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 56, 1},
         {7, 56, 1},
         {8, 56, 1},
         {9, 53, 1},
         {10, 53, 1},
         {11, 53, 1}
       ]},
      {26,
       [
         {0, 73, 1.5},
         {1.5, 75, 0.25},
         {1.75, 77, 0.25},
         {2, 78, 0.25},
         {2.25, 80, 0.25},
         {2.5, 81, 0.25},
         {2.75, 80, 0.25},
         {3, 83, 1},
         {4, 81, 1},
         {5, 80, 1},
         {6, 78, 5}
       ], [{9, 73, 1.5}, {10.5, 71, 0.5}, {11, 69, 0.5}, {11.5, 68, 0.5}],
       [
         {0, 61, 1},
         {0, 69, 1},
         {1, 68, 1},
         {1, 71, 1},
         {1, 77, 1},
         {2, 69, 1},
         {2, 73, 1},
         {2, 78, 1},
         {3, 68, 1},
         {3, 73, 1},
         {3, 80, 0.25},
         {3.25, 81, 0.25},
         {3.5, 83, 0.5},
         {4, 69, 1},
         {4, 78, 1},
         {4, 81, 1},
         {5, 71, 1},
         {5, 77, 1},
         {5, 80, 1},
         {6, 69, 5},
         {6, 73, 5},
         {6, 78, 5}
       ],
       [
         {0, 57, 1},
         {1, 56, 1},
         {2, 54, 1},
         {3, 61, 1},
         {4, 61, 1},
         {5, 49, 1},
         {6, 54, 1},
         {7, 57, 1},
         {8, 49, 1},
         {9, 54, 1},
         {10, 45, 1},
         {11, 49, 1}
       ]},
      {27, [{1.5, 84, 0.5}, {2, 81, 1}, {3, 76, 1.5}, {4.5, 84, 0.5}, {5, 81, 1}, {6, 75, 2}],
       [
         {0, 69, 7.5},
         {7.5, 69, 0.25},
         {7.75, 71, 0.25},
         {8, 72, 2.5},
         {10.5, 71, 0.5},
         {11, 69, 1}
       ],
       [
         {0, 66, 1},
         {0, 69, 1},
         {0, 78, 7.5},
         {1, 68, 1},
         {1, 71, 1},
         {2, 69, 1},
         {2, 72, 1},
         {3, 69, 1},
         {3, 72, 1},
         {4, 67, 1},
         {4, 71, 1},
         {5, 69, 1},
         {5, 72, 1},
         {6, 66, 1},
         {6, 71, 1},
         {7, 64, 1},
         {7, 73, 1},
         {7.5, 78, 0.25},
         {7.75, 79, 0.25},
         {8, 66, 1},
         {8, 75, 1},
         {8, 81, 1},
         {9, 66, 2},
         {9, 75, 2},
         {9, 81, 1.5},
         {10.5, 79, 0.5},
         {11, 78, 1}
       ], [{0, 42, 2}, {6, 59, 1}, {7, 59, 1}, {8, 59, 1}, {9, 59, 1}, {10, 59, 1}, {11, 47, 1}]},
      {28, [{1.5, 79, 0.5}, {2, 76, 1}, {3, 72, 1.5}, {4.5, 79, 0.5}, {5, 76, 1}, {6, 70, 2}],
       [{0, 67, 7}, {7, 66, 1}, {8, 68, 1}, {9, 70, 1}, {10, 71, 1}, {11, 73, 1}],
       [
         {0, 59, 1},
         {0, 64, 1},
         {0, 76, 7},
         {1, 63, 1},
         {1, 66, 1},
         {2, 64, 1},
         {2, 67, 1},
         {3, 64, 1},
         {3, 67, 1},
         {4, 63, 1},
         {4, 66, 1},
         {5, 64, 1},
         {5, 67, 1},
         {6, 54, 1},
         {6, 73, 1},
         {7, 61, 1},
         {7, 64, 1},
         {7, 70, 1},
         {8, 62, 1},
         {8, 62, 1},
         {8, 71, 11.5},
         {9, 64, 2},
         {9, 71, 2},
         {9, 73, 0.5},
         {9.5, 74, 0.5},
         {10, 76, 1},
         {11, 70, 1}
       ], [{0, 52, 2}, {6, 42, 1}, {7, 42, 1}, {8, 42, 1}, {9, 42, 1}, {10, 42, 1}, {11, 42, 1}]},
      {29, [{1.5, 86, 0.5}, {2, 83, 1}, {3, 79, 1.5}, {4.5, 86, 0.5}, {5, 83, 1}, {6, 77, 2}],
       [{0, 74, 7.5}, {7.5, 73, 0.5}, {8, 71, 1}, {9, 74, 1.5}, {10.5, 73, 0.5}, {11, 71, 1}],
       [
         {0, 62, 1},
         {0, 66, 1},
         {1, 64, 1},
         {1, 70, 1},
         {2, 66, 1},
         {2, 71, 1},
         {3, 67, 1},
         {3, 71, 1},
         {4, 64, 1},
         {4, 70, 1},
         {5, 66, 1},
         {5, 71, 1},
         {6, 56, 2},
         {6, 61, 1},
         {7, 63, 1},
         {7.5, 69, 0.5},
         {8, 65, 1},
         {8, 68, 1},
         {9, 65, 2},
         {9, 68, 2},
         {9, 71, 1.5},
         {10.5, 69, 0.5},
         {11, 68, 1}
       ], [{0, 47, 2}, {6, 49, 1}, {7, 49, 1}, {8, 49, 1}, {9, 49, 1}, {10, 49, 1}, {11, 49, 1}]},
      {30,
       [
         {0, 81, 0.25},
         {0.25, 83, 0.25},
         {0.5, 85, 1},
         {1.5, 83, 0.25},
         {1.75, 81, 0.25},
         {2, 83, 0.25},
         {2.25, 81, 0.25},
         {2.5, 80, 0.5},
         {3, 78, 0.25},
         {3.25, 80, 0.25},
         {3.5, 81, 1},
         {4.5, 80, 0.25},
         {4.75, 78, 0.25},
         {5, 80, 0.25},
         {5.25, 78, 0.25},
         {5.5, 76, 0.5},
         {6, 74, 0.25},
         {6.25, 76, 0.25},
         {6.5, 78, 1},
         {7.5, 76, 0.25},
         {7.75, 75, 0.25},
         {8, 76, 0.25},
         {8.25, 75, 0.25},
         {8.5, 73, 0.5},
         {9, 72, 1}
       ],
       [
         {0, 69, 1},
         {1, 66, 1},
         {2, 68, 1},
         {3, 69, 3},
         {6, 69, 1},
         {7, 72, 1},
         {8, 73, 1},
         {9, 75, 1},
         {10, 66, 1},
         {11, 69, 1}
       ],
       [
         {0, 57, 3},
         {0, 61, 3},
         {0, 66, 3},
         {3, 61, 3},
         {3, 66, 3},
         {3, 69, 3},
         {6, 66, 3},
         {6, 69, 3},
         {6, 74, 2},
         {8, 73, 1},
         {9, 60, 1},
         {9, 68, 1},
         {9, 80, 1},
         {11, 68, 1},
         {11, 75, 1}
       ],
       [
         {0, 42, 1},
         {1, 42, 1},
         {2, 42, 1},
         {3, 42, 1},
         {4, 42, 1},
         {5, 42, 1},
         {6, 42, 1},
         {7, 42, 1},
         {8, 42, 1},
         {9, 54, 1},
         {10, 51, 1},
         {11, 48, 1}
       ]},
      {31,
       [
         {4.5, 81, 0.5},
         {5, 78, 1},
         {6, 74, 1.5},
         {7.5, 81, 0.5},
         {8, 78, 1},
         {9, 73, 1.5},
         {10.5, 81, 0.5},
         {11, 78, 1}
       ],
       [
         {0, 68, 1.5},
         {1.5, 73, 0.5},
         {2, 69, 1},
         {3, 66, 4},
         {7, 65, 1},
         {8, 66, 1},
         {9, 69, 1},
         {10, 74, 0.5},
         {10.5, 72, 0.5},
         {11, 73, 1}
       ],
       [
         {0, 68, 2},
         {0, 73, 2},
         {3, 66, 9},
         {3, 69, 6},
         {3, 73, 3},
         {6, 74, 3},
         {9, 69, 3},
         {9, 73, 3}
       ],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 54, 1},
         {7, 54, 1},
         {8, 54, 1},
         {9, 52, 1},
         {10, 52, 1},
         {11, 52, 1}
       ]},
      {32, [{0, 72, 2}, {11, 73, 1}],
       [
         {0, 66, 1.5},
         {1.5, 69, 0.5},
         {2, 68, 1},
         {3, 68, 1},
         {4, 66, 0.5},
         {4.5, 64, 0.5},
         {5, 63, 0.5},
         {5.5, 61, 0.5},
         {6, 61, 5}
       ],
       [
         {0, 66, 2},
         {0, 69, 2},
         {0, 72, 2},
         {2, 63, 1},
         {2, 72, 1},
         {3, 68, 3},
         {3, 73, 2},
         {5, 72, 1},
         {6, 65, 6},
         {6, 68, 1},
         {7, 68, 1},
         {8, 71, 2},
         {9, 73, 3},
         {10, 69, 1},
         {11, 68, 1}
       ],
       [
         {0, 51, 1},
         {1, 52, 1},
         {2, 54, 1},
         {3, 52, 1},
         {4, 54, 1},
         {5, 56, 1},
         {6, 49, 1},
         {7, 49, 1},
         {8, 49, 1},
         {9, 53, 1},
         {10, 53, 1},
         {11, 53, 1}
       ]},
      {33,
       [
         {0, 81, 1.5},
         {1.5, 80, 0.25},
         {1.75, 81, 0.25},
         {2, 83, 1},
         {3, 83, 1.5},
         {4.5, 81, 0.5},
         {5, 80, 1},
         {6, 78, 13.5}
       ], [{11, 66, 1}],
       [
         {0, 66, 3},
         {0, 69, 3},
         {0, 73, 3},
         {3, 68, 1},
         {3, 73, 2},
         {3, 77, 3},
         {4, 69, 1},
         {5, 61, 1},
         {5, 71, 1},
         {6, 66, 6},
         {6, 69, 2},
         {6, 78, 3},
         {8, 71, 1},
         {9, 73, 3},
         {9, 76, 3}
       ],
       [
         {0, 54, 1},
         {1, 54, 1},
         {2, 54, 1},
         {3, 49, 1},
         {4, 49, 1},
         {5, 49, 1},
         {6, 50, 1},
         {7, 50, 1},
         {8, 50, 1},
         {9, 46, 1},
         {10, 46, 1},
         {11, 46, 1}
       ]},
      {34, [{7.5, 83, 0.5}, {8, 79, 1}, {9, 71, 1.5}, {10.5, 81, 0.5}, {11, 78, 1}],
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 1},
         {3, 76, 1.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 71, 2},
         {8, 64, 1},
         {9, 63, 2},
         {11, 71, 1}
       ],
       [
         {0, 66, 5},
         {0, 71, 3},
         {0, 74, 3},
         {3, 70, 3},
         {3, 73, 3},
         {5, 64, 1},
         {6, 62, 2},
         {6, 71, 3},
         {6, 71, 3},
         {8, 64, 1},
         {9, 66, 3},
         {9, 71, 2},
         {9, 78, 3},
         {11, 75, 1}
       ],
       [
         {0, 47, 1},
         {1, 47, 1},
         {2, 47, 1},
         {3, 42, 1},
         {4, 42, 1},
         {5, 42, 1},
         {6, 43, 1},
         {7, 43, 1},
         {8, 43, 1},
         {9, 47, 1},
         {10, 47, 1},
         {11, 47, 1}
       ]},
      {35,
       [
         {0, 67, 1.5},
         {1.5, 79, 0.5},
         {2, 76, 1},
         {3, 71, 1.5},
         {4.5, 79, 0.5},
         {5, 76, 1},
         {6, 70, 1.5},
         {7.5, 76, 0.25},
         {7.75, 78, 0.25},
         {8, 79, 2.5},
         {10.5, 78, 0.5},
         {11, 76, 1}
       ], [{0, 72, 2}, {2, 71, 1}, {3, 71, 2}, {5, 70, 1}, {6, 70, 2}, {8, 71, 1}, {9, 73, 4.5}],
       [{0, 64, 6}, {0, 76, 6}, {0, 79, 9}, {6, 52, 3}, {6, 76, 6}, {9, 58, 3}, {9, 73, 3}],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 50, 1},
         {4, 50, 1},
         {5, 50, 1},
         {6, 49, 1},
         {7, 49, 1},
         {8, 49, 1},
         {9, 46, 1},
         {10, 46, 1},
         {11, 46, 1}
       ]},
      {36,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 2.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 70, 5}
       ],
       [
         {1.5, 70, 0.5},
         {2, 71, 1},
         {3, 73, 0.5},
         {3.5, 74, 0.5},
         {4, 76, 1},
         {5, 73, 1},
         {6, 70, 2},
         {8, 68, 1},
         {9, 66, 2},
         {11, 64, 1}
       ],
       [
         {0, 66, 3},
         {0, 74, 3},
         {0, 74, 3},
         {3, 67, 3},
         {3, 71, 3},
         {3, 76, 3},
         {6, 61, 1},
         {6, 70, 1},
         {6, 78, 5},
         {7, 62, 1},
         {7, 71, 1},
         {8, 64, 1},
         {8, 73, 1},
         {9, 58, 1},
         {9, 61, 1},
         {10, 59, 1},
         {10, 62, 1},
         {11, 61, 1},
         {11, 64, 1},
         {11, 70, 1}
       ], [{0, 47, 1}, {1, 47, 1}, {2, 47, 1}, {3, 43, 1}, {4, 43, 1}, {5, 43, 1}, {6, 54, 2}]},
      {37, [{7.5, 76, 0.5}, {8, 71, 1}, {9, 67, 2}],
       [
         {0, 63, 1},
         {1, 66, 0.5},
         {1.5, 69, 0.5},
         {2, 72, 2.5},
         {4.5, 71, 0.5},
         {5, 69, 1},
         {6, 67, 5},
         {11, 71, 1}
       ],
       [
         {0, 59, 1},
         {0, 66, 1},
         {0, 72, 1.5},
         {1, 59, 1},
         {1, 66, 1},
         {1.5, 71, 0.5},
         {2, 59, 1},
         {2, 66, 1},
         {2, 69, 1},
         {3, 59, 1},
         {3, 66, 1},
         {3, 75, 1.5},
         {4, 59, 1},
         {4, 66, 1},
         {4.5, 76, 0.5},
         {5, 59, 1},
         {5, 66, 1},
         {5, 78, 1},
         {6, 59, 1},
         {6, 67, 1},
         {6, 78, 1},
         {7, 55, 1},
         {7, 64, 1},
         {7, 76, 4},
         {8, 57, 1},
         {8, 66, 1},
         {9, 59, 1},
         {9, 67, 1},
         {10, 61, 1},
         {10, 64, 1},
         {11, 59, 1},
         {11, 62, 1},
         {11, 67, 1}
       ], [{0, 47, 2}, {6, 52, 2}]},
      {38, [{7.5, 71, 0.5}, {8, 66, 1}, {9, 62, 2}, {11, 66, 1}],
       [
         {0, 64, 1.5},
         {1.5, 66, 0.5},
         {2, 67, 2.5},
         {4.5, 66, 0.5},
         {5, 64, 1},
         {6, 62, 2},
         {8, 61, 1},
         {9, 62, 1.5},
         {10.5, 66, 0.5},
         {11, 64, 1}
       ],
       [
         {0, 58, 1},
         {0, 61, 1},
         {0, 67, 1.5},
         {1, 59, 1},
         {1, 62, 1},
         {1.5, 66, 0.5},
         {2, 61, 1},
         {2, 64, 1},
         {2, 64, 1},
         {3, 54, 1},
         {3, 64, 1},
         {3, 70, 1.5},
         {4, 54, 1},
         {4, 62, 1},
         {4.5, 71, 0.5},
         {5, 54, 1},
         {5, 61, 1},
         {5, 73, 1},
         {6, 54, 1},
         {6, 62, 1},
         {6, 73, 1},
         {7, 50, 1},
         {7, 59, 1},
         {7, 71, 4},
         {8, 52, 1},
         {8, 58, 1},
         {9, 54, 1},
         {9, 59, 1},
         {10, 62, 1},
         {10, 71, 1},
         {11, 61, 1},
         {11, 70, 1},
         {11, 73, 1}
       ], [{0, 54, 2}, {6, 47, 2}]},
      {39,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.5},
         {2, 71, 1},
         {3, 71, 1.5},
         {4.5, 70, 0.5},
         {5, 71, 1},
         {6, 71, 8}
       ], [{0, 66, 7.5}, {7.5, 64, 0.5}, {8, 63, 2.5}, {10.5, 64, 0.5}, {11, 66, 1}],
       [
         {0, 59, 9},
         {0, 71, 9},
         {0, 74, 7},
         {7, 73, 1},
         {8, 71, 1},
         {9, 66, 1},
         {9, 69, 1},
         {9, 75, 3},
         {10, 67, 1},
         {10, 67, 1},
         {11, 66, 1},
         {11, 69, 1}
       ],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 57, 1},
         {4, 57, 1},
         {5, 57, 1},
         {6, 55, 1},
         {7, 55, 1},
         {8, 55, 1},
         {9, 54, 1},
         {10, 54, 1},
         {11, 54, 1}
       ]},
      {40,
       [
         {2, 76, 1},
         {3, 76, 1},
         {4, 75, 1},
         {5, 81, 2},
         {7, 79, 0.5},
         {7.5, 81, 0.5},
         {8, 78, 2},
         {10, 76, 0.5},
         {10.5, 79, 0.5},
         {11, 74, 1}
       ],
       [
         {0, 67, 1.5},
         {1.5, 66, 0.25},
         {1.75, 67, 0.25},
         {2, 69, 2.5},
         {4.5, 67, 0.5},
         {5, 66, 1},
         {6, 64, 5},
         {11, 67, 1}
       ],
       [
         {0, 67, 3},
         {0, 71, 6},
         {0, 76, 3},
         {3, 66, 3},
         {3, 81, 2},
         {5, 75, 1},
         {6, 64, 6},
         {6, 71, 6},
         {6, 76, 3},
         {9, 71, 3}
       ],
       [
         {0, 52, 1},
         {1, 52, 1},
         {2, 52, 1},
         {3, 54, 1},
         {4, 54, 1},
         {5, 54, 1},
         {6, 55, 1},
         {7, 52, 1},
         {8, 55, 1},
         {9, 59, 1},
         {10, 55, 1},
         {11, 59, 1}
       ]},
      {41,
       [
         {0, 72, 1.5},
         {1.5, 79, 0.5},
         {2, 76, 1},
         {3, 71, 1.5},
         {4.5, 79, 0.5},
         {5, 76, 1},
         {6, 70, 1.5},
         {7.5, 76, 0.25},
         {7.75, 78, 0.25},
         {8, 79, 2.5},
         {10.5, 78, 0.5},
         {11, 76, 1}
       ],
       [
         {0, 72, 2},
         {2, 71, 1},
         {3, 71, 2},
         {5, 70, 1},
         {6, 70, 1.5},
         {7.5, 64, 0.25},
         {7.75, 66, 0.25},
         {8, 67, 2.5},
         {10.5, 64, 0.5},
         {11, 66, 1}
       ],
       [
         {0, 64, 9},
         {0, 67, 9},
         {0, 72, 3},
         {3, 76, 6},
         {9, 64, 2},
         {9, 73, 3},
         {9, 76, 1},
         {10, 74, 1},
         {11, 66, 1},
         {11, 73, 1}
       ],
       [
         {0, 64, 1},
         {1, 64, 1},
         {2, 64, 1},
         {3, 62, 1},
         {4, 62, 1},
         {5, 62, 1},
         {6, 61, 1},
         {7, 61, 1},
         {8, 61, 1},
         {9, 58, 1},
         {10, 58, 1},
         {11, 58, 1}
       ]},
      {42,
       [
         {0, 74, 1.5},
         {1.5, 73, 0.25},
         {1.75, 74, 0.25},
         {2, 76, 2.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 70, 3.5},
         {9.5, 61, 0.5},
         {10, 66, 0.5},
         {10.5, 70, 0.5},
         {11, 73, 0.5},
         {11.5, 74, 0.5}
       ],
       [
         {0, 74, 1.5},
         {1.5, 73, 0.5},
         {2, 76, 2.5},
         {4.5, 74, 0.5},
         {5, 73, 1},
         {6, 70, 2},
         {8, 68, 1},
         {9, 66, 2}
       ], [{0, 59, 6}, {0, 71, 6}, {0, 78, 3}, {3, 76, 3}, {6, 66, 5}, {6, 73, 5}, {6, 78, 5}],
       [
         {0, 59, 1},
         {1, 59, 1},
         {2, 59, 1},
         {3, 55, 1},
         {4, 55, 1},
         {5, 55, 1},
         {6, 54, 1},
         {7, 49, 1},
         {8, 52, 1},
         {9, 52, 1},
         {10, 46, 1},
         {11, 49, 1}
       ]},
      {43,
       [
         {0, 76, 0.25},
         {0.25, 74, 0.25},
         {0.5, 73, 0.5},
         {1, 71, 1},
         {2, 70, 0.75},
         {2.75, 71, 0.25},
         {3, 73, 0.25},
         {3.25, 71, 0.25},
         {3.5, 70, 0.5},
         {4, 67, 1},
         {5, 66, 0.75},
         {5.75, 67, 0.25},
         {6, 70, 2}
       ], [{5, 73, 1}, {6, 64, 1.5}, {7.5, 66, 0.5}, {8, 67, 2.5}, {10.5, 66, 0.5}, {11, 64, 1}],
       [
         {0, 61, 1},
         {0, 66, 1},
         {0, 70, 1},
         {1, 62, 1},
         {1, 68, 1},
         {1, 71, 1},
         {2, 64, 1},
         {2, 70, 1},
         {2, 73, 1},
         {3, 54, 1},
         {3, 70, 1},
         {3, 73, 1},
         {4, 54, 1},
         {4, 71, 1},
         {4, 74, 1},
         {5, 54, 1},
         {5, 73, 1},
         {5, 76, 1},
         {6, 54, 5},
         {6, 61, 5},
         {6, 70, 5}
       ], [{0, 42, 2}, {6, 42, 1}, {7, 42, 1}, {8, 42, 1}, {9, 42, 1}, {10, 42, 1}, {11, 42, 1}]},
      {44,
       [
         {0, 81, 0.25},
         {0.25, 79, 0.25},
         {0.5, 78, 0.5},
         {1, 76, 1},
         {2, 75, 0.75},
         {2.75, 76, 0.25},
         {3, 78, 0.25},
         {3.25, 76, 0.25},
         {3.5, 75, 0.5},
         {4, 72, 1},
         {5, 71, 0.75},
         {5.75, 72, 0.25},
         {6, 75, 2}
       ],
       [
         {0, 63, 2},
         {2, 59, 1},
         {3, 69, 1.5},
         {4.5, 66, 0.5},
         {5, 63, 0.5},
         {5.5, 64, 0.5},
         {6, 69, 1.5},
         {7.5, 71, 0.5},
         {8, 72, 2.5},
         {10.5, 71, 0.5},
         {11, 69, 1}
       ],
       [
         {0, 54, 1},
         {0, 63, 1},
         {0, 66, 1},
         {1, 59, 1},
         {1, 64, 1},
         {1, 67, 1},
         {2, 59, 1},
         {2, 66, 1},
         {2, 69, 1},
         {3, 59, 1},
         {3, 63, 1},
         {3, 66, 1},
         {4, 59, 1},
         {4, 64, 1},
         {4, 67, 1},
         {5, 59, 1},
         {5, 66, 1},
         {5, 69, 1},
         {6, 59, 5},
         {6, 66, 5},
         {6, 69, 5}
       ], [{0, 47, 2}, {6, 47, 1}, {7, 47, 1}, {8, 47, 1}, {9, 47, 1}, {10, 47, 1}, {11, 47, 1}]},
      {45,
       [
         {0, 79, 0.25},
         {0.25, 81, 0.25},
         {0.5, 83, 1},
         {1.5, 81, 0.25},
         {1.75, 79, 0.25},
         {2, 81, 0.25},
         {2.25, 79, 0.25},
         {2.5, 78, 0.5},
         {3, 76, 0.25},
         {3.25, 78, 0.25},
         {3.5, 79, 1},
         {4.5, 78, 0.25},
         {4.75, 76, 0.25},
         {5, 78, 0.25},
         {5.25, 76, 0.25},
         {5.5, 74, 0.5},
         {6, 72, 0.25},
         {6.25, 74, 0.25},
         {6.5, 76, 1},
         {7.5, 74, 0.25},
         {7.75, 72, 0.25},
         {8, 74, 0.25},
         {8.25, 72, 0.25},
         {8.5, 71, 0.5},
         {9, 70, 0.25},
         {9.25, 71, 0.25},
         {9.5, 73, 1},
         {10.5, 71, 0.25},
         {10.75, 70, 0.25},
         {11, 71, 0.25},
         {11.25, 70, 0.25},
         {11.5, 68, 0.5}
       ],
       [
         {0, 67, 1},
         {1, 69, 1},
         {2, 71, 2},
         {4, 73, 1},
         {5, 75, 1},
         {6, 76, 1.5},
         {7.5, 74, 0.25},
         {7.75, 72, 0.25},
         {8, 71, 0.5},
         {8.5, 69, 0.5},
         {9, 67, 1},
         {10, 66, 0.5},
         {10.5, 64, 0.5},
         {11, 62, 0.5},
         {11.5, 61, 0.5}
       ],
       [
         {0, 59, 3},
         {0, 64, 3},
         {0, 67, 3},
         {3, 64, 3},
         {3, 67, 3},
         {3, 71, 3},
         {6, 67, 3},
         {6, 72, 3},
         {6, 76, 3},
         {9, 67, 1},
         {9, 73, 1},
         {9, 76, 1},
         {10, 66, 2},
         {10, 70, 2},
         {10, 73, 2}
       ],
       [
         {0, 40, 1},
         {1, 40, 1},
         {2, 40, 1},
         {3, 40, 1},
         {4, 40, 1},
         {5, 40, 1},
         {6, 40, 1},
         {7, 40, 1},
         {8, 40, 1},
         {9, 40, 1},
         {10, 40, 1},
         {11, 52, 1}
       ]},
      {46, [{0, 66, 1}, {11, 66, 1}],
       [
         {0, 66, 1.5},
         {1.5, 68, 0.25},
         {1.75, 70, 0.25},
         {2, 71, 0.25},
         {2.25, 73, 0.25},
         {2.5, 74, 0.25},
         {2.75, 73, 0.25},
         {3, 76, 1},
         {4, 74, 1},
         {5, 73, 1},
         {6, 71, 3},
         {9, 71, 2}
       ],
       [
         {0, 66, 1},
         {0, 71, 1},
         {1, 66, 1},
         {1, 70, 1},
         {2, 62, 1},
         {2, 71, 1},
         {3, 61, 3},
         {3, 66, 3},
         {3, 71, 2},
         {5, 70, 1},
         {6, 62, 3},
         {6, 66, 3},
         {6, 71, 3},
         {9, 62, 2},
         {9, 66, 2}
       ],
       [
         {0, 50, 1},
         {1, 49, 1},
         {2, 47, 1},
         {3, 54, 1},
         {4, 54, 1},
         {5, 42, 1},
         {6, 47, 1},
         {7, 38, 1},
         {8, 42, 1},
         {9, 47, 1},
         {10, 50, 1},
         {11, 54, 1}
       ]}
    ]
  end
end
