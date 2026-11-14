Code.require_file("score.exs", __DIR__)

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
  The notes are those of score.exs beside this song.
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
          {^bar, violin, alto, inner, bass} = ErbarmeDich.Score.bar(bar),
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
end
