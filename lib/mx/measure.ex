defmodule Mx.Measure do
  @moduledoc """
  Measures recordings of single notes, plucked or struck, so a synth's design can be compared with
  a real instrument's.

  A file holds one note or several, one after another a semitone apart, each starting from
  silence.
  Rumble below the file's lowest note is filtered out, and a note starts where the level rises 20
  dB within 200 ms, at least 2 seconds after the one before.
  For each note it finds the pitch, how far the harmonics are stretched sharp, and for each
  harmonic its frequency, its level in dB as the note starts, and the seconds it takes to fade 60
  dB.
  Each harmonic is looked for one step above the last, since a stiff string's harmonics drift
  sharp.
  """

  alias Mx.Engine.Mxs.Native
  alias Mx.Signal

  @doc """
  Measures each note of a recording that starts on `note`, and returns `{:ok, notes}` or
  `{:error, message}` naming the file.
  """
  def file(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_data(path, "notes", &Native.measure_plucked(&1, &2, &3, note, false))
  end

  @doc """
  Measures the note a recording of a struck note starts with, partial by partial, over its first
  2.9 seconds, before NSynth lets its notes go.
  Spectra every 2.5 ms, through windows eight periods of the fundamental long, from 80 to 250 ms,
  follow each partial's level, solved together so none takes in its neighbours'.
  The partials are the harmonics up to 8 kHz or the highest the recording holds, and the peaks
  between them as the note starts, each kept while it stands 10 dB above the noise floor of its
  third of an octave.
  A partial between harmonics with no strike and hardly any fall is a line that is not the
  instrument's, and is left out.
  Returns `{:ok, %{pitch: hz, partials: partials, left_out: lines}}`, each partial with its
  `freq`, its `harmonic` number or 0 between harmonics, its `level` as the note starts in dB
  against the loudest, and how it falls: `fall` in dB a second, and where it slows, the `knee` in
  seconds and the slope it falls at `then`.
  """
  def partials(path, note) when is_binary(path) and is_integer(note) do
    with {:ok, [measured]} <-
           Signal.measure_data(path, "a note", &[Native.measure_struck(&1, &2, &3, note / 1)]) do
      {:ok, measured}
    end
  end

  @doc """
  Measures each note of a sound whose first note is `first`, one after another a semitone apart.
  """
  def notes(samples, rate, first)
      when is_list(samples) and is_integer(rate) and is_integer(first) do
    {data, format} = Signal.packed(samples)
    Native.measure_plucked(data, format, rate / 1, first, false)
  end

  @doc """
  Measures a sound that is one note from its first sample, such as a synth rendered offline, or
  returns nil when it is too short.
  """
  def note(samples, rate, note) when is_list(samples) and is_integer(rate) and is_integer(note) do
    {data, format} = Signal.packed(samples)
    data |> Native.measure_plucked(format, rate / 1, note, true) |> List.first()
  end

  @doc """
  The median fade and level of the notes' harmonics in each band, with levels against the
  fundamental of the lowest note.
  """
  def bands(notes) when is_list(notes) do
    lowest = notes |> Enum.map(& &1.note) |> Enum.min()

    reference =
      Signal.median(for %{note: ^lowest, harmonics: [first | _]} <- notes, do: first.level)

    harmonics = Enum.flat_map(notes, & &1.harmonics)

    for {low, high} = band <- Signal.bands(),
        inside = Enum.filter(harmonics, &(&1.freq >= low and &1.freq < high)),
        inside != [] do
      fades = for %{fade: fade} <- inside, fade != nil, do: fade
      fade = if fades == [], do: nil, else: Signal.median(fades)
      median = inside |> Enum.map(& &1.level) |> Signal.median()
      level = median - reference
      %{band: band, fade: fade, level: level, count: length(inside)}
    end
  end

  @doc "A note number as mx writes it, such as `as2`."
  def name(note) when is_integer(note) do
    names = ~w(c cs d ds e f fs g gs a as b)
    letter = Enum.at(names, rem(note, 12))
    octave = div(note, 12) - 1
    "#{letter}#{octave}"
  end
end
