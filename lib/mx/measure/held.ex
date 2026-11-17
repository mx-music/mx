defmodule Mx.Measure.Held do
  @moduledoc """
  Measures recordings of held notes, bowed, blown or played on an organ, so a synth's design can be compared with a real instrument's.

  A file holds one note or several, one after another a semitone apart, each starting from silence.
  The held part of a note is its longest stretch within 12 dB of its loudest.
  For each note it finds the pitch, the attack, the level of each harmonic while the note holds, the vibrato, and the noise between the harmonics.
  The attack is the seconds from the start of the sound until it first comes within 0.5 dB of its held level.
  The vibrato is the swing of the pitch, found from its repeats between 3 and 10 times a second, and there is none when the pitch swings less than 5 cents or does not repeat.
  The noise is the power between the harmonics in each band, given in dB as the level of a harmonic of the same power.
  """

  alias Mx.Engine.Mxs.Native
  alias Mx.Signal

  @doc "Measures each held note of a recording that starts on `note`, and returns `{:ok, notes}` or `{:error, message}` naming the file."
  def file(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_data(path, "notes", &Native.measure_held(&1, &2, &3, note, false))
  end

  @doc "Measures a recording as one note on `note` held from its first sample to its last, such as a drone plucked again and again, and returns `{:ok, [note]}` or `{:error, message}` naming the file."
  def drone(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_data(path, "drone", &Native.measure_held(&1, &2, &3, note, true))
  end

  @doc "Measures each held note of a sound whose first note is `first`, one after another a semitone apart."
  def notes(samples, rate, first)
      when is_list(samples) and is_integer(rate) and is_integer(first) do
    {data, format} = Signal.packed(samples)
    Native.measure_held(data, format, rate / 1, first, false)
  end

  @doc "Measures a sound that is one held note from its first sample, such as a synth rendered offline, or returns nil when it is too short."
  def note(samples, rate, note) when is_list(samples) and is_integer(rate) and is_integer(note) do
    {data, format} = Signal.packed(samples)
    data |> Native.measure_held(format, rate / 1, note, true) |> List.first()
  end

  @doc """
  The median attack and vibrato of the notes, and for each band the median level of their harmonics and of their noise, against the fundamental of the lowest note.

  The vibrato is nil unless at least half the notes have one.
  """
  def summary(notes) when is_list(notes) do
    lowest = notes |> Enum.map(& &1.note) |> Enum.min()

    reference =
      Signal.median(for %{note: ^lowest, harmonics: [first | _]} <- notes, do: first.level)

    vibratos = for %{vibrato: %{} = vibrato} <- notes, do: vibrato

    vibrato =
      if length(vibratos) * 2 >= length(notes) do
        %{
          rate: Signal.median(Enum.map(vibratos, & &1.rate)),
          depth: Signal.median(Enum.map(vibratos, & &1.depth))
        }
      end

    harmonics = Enum.flat_map(notes, & &1.harmonics)
    noises = Enum.flat_map(notes, & &1.noise)

    bands =
      for {low, high} = band <- Signal.bands(),
          levels = levels(harmonics, low, high),
          noise = Enum.flat_map(noises, &if(&1.band == band, do: [&1.level], else: [])),
          levels != [] or noise != [] do
        %{
          band: band,
          level: relative(levels, reference),
          noise: relative(noise, reference),
          count: length(levels)
        }
      end

    %{attack: Signal.median(Enum.map(notes, & &1.attack)), vibrato: vibrato, bands: bands}
  end

  defp levels(harmonics, low, high) do
    for %{freq: freq, level: level} <- harmonics, freq >= low and freq < high, do: level
  end

  defp relative([], _reference), do: nil
  defp relative(levels, reference), do: Signal.median(levels) - reference
end
