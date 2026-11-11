defmodule Mx.Measure do
  @moduledoc """
  Measures recordings of single notes, plucked or struck, so a synth's design can be compared with a real instrument's.

  A file holds one note or several, one after another a semitone apart, each starting from silence.
  Rumble below the file's lowest note is filtered out, and a note starts where the level rises 20 dB within 200 ms, at least 2 seconds after the one before.
  For each note it finds the pitch, how far the harmonics are stretched sharp, and for each harmonic its frequency, its level in dB as the note starts, and the seconds it takes to fade 60 dB.
  Each harmonic is looked for one step above the last, since a stiff string's harmonics drift sharp.
  """

  alias Mx.Signal

  @fft 16_384
  @first 0.02
  @hop 0.1
  @longest 4.0
  @harmonics 24

  @doc "Measures each note of a recording that starts on `note`, and returns `{:ok, notes}` or `{:error, message}` naming the file."
  def file(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_file(path, "notes", &notes(&1, &2, note))
  end

  @doc "Measures each note of a sound whose first note is `first`, one after another a semitone apart."
  def notes(samples, rate, first)
      when is_list(samples) and is_integer(rate) and is_integer(first) do
    cutoff = Signal.hz(first) * 0.75
    filtered = Signal.high_pass(samples, rate, cutoff)
    sound = List.to_tuple(filtered)
    starts = Signal.onsets(filtered, rate, 2)
    ends = Enum.drop(starts, 1) ++ [tuple_size(sound)]
    longest = round((@first + @longest) * rate) + @fft

    Enum.zip(starts, ends)
    |> Enum.with_index(fn {from, to}, index ->
      segment = for at <- from..(min(to, from + longest) - 1)//1, do: elem(sound, at)
      {segment, first + index}
    end)
    |> Task.async_stream(fn {segment, guess} -> measure(segment, rate, guess, cutoff) end,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
  end

  @doc "Measures a sound that is one note from its first sample, such as a synth rendered offline, or returns nil when it is too short."
  def note(samples, rate, note) when is_list(samples) and is_integer(rate) and is_integer(note) do
    longest = round((@first + @longest) * rate) + @fft
    cutoff = Signal.hz(note) * 0.75
    samples |> Signal.high_pass(rate, cutoff) |> Enum.take(longest) |> measure(rate, note, cutoff)
  end

  @doc "The median fade and level of the notes' harmonics in each band, with levels against the fundamental of the lowest note."
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
      level = Signal.median(Enum.map(inside, & &1.level)) - reference
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

  defp measure(segment, rate, guess, cutoff) do
    sound = List.to_tuple(segment)
    last = min((tuple_size(sound) - @fft) / rate, @longest)
    frames = max(floor((last - @first) / @hop), -1)
    times = for frame <- 0..frames//1, do: @first + frame * @hop

    if length(times) < 5 do
      nil
    else
      spectra = Enum.map(times, &Signal.spectrum(sound, round(&1 * rate), @fft))
      bin = rate / @fft
      f0 = pitch(hd(spectra), Signal.hz(guess), bin)
      harmonics = harmonics(spectra, times, f0, bin, rate, cutoff)

      %{
        note: round(69 + 12 * :math.log2(f0 / 440)),
        pitch: f0,
        stretch: stretch(harmonics, f0),
        harmonics: harmonics
      }
    end
  end

  # The fundamental within 6% of the guess whose first six harmonics hold the most energy.
  defp pitch(spectrum, guess, bin) do
    steps = round(guess * 0.12 / 0.05)

    0..steps
    |> Enum.map(&(guess * 0.94 + &1 * 0.05))
    |> Enum.max_by(fn freq ->
      Enum.sum(for number <- 1..6, do: Signal.magnitude_at(spectrum, freq * number / bin))
    end)
  end

  # A harmonic less than 10 dB above the noise floor, or 80 dB below the loudest, is absent.
  # The next is then looked for one step above where it should have been.
  defp harmonics(spectra, times, f0, bin, rate, cutoff) do
    [first | _] = spectra
    floor = first |> Tuple.to_list() |> Enum.map(&Signal.db/1) |> Signal.median()
    context = %{spectra: spectra, times: times, f0: f0, bin: bin, cutoff: cutoff, floor: floor}
    top = min(18_000, rate / 2 - f0)

    {rows, _} =
      Enum.reduce_while(1..@harmonics, {[], {0.0, f0}}, fn number, {rows, {before, last}} ->
        target = if number == 1, do: f0, else: 2 * last - before

        if target > top or (target <= last and number > 1) do
          {:halt, {rows, nil}}
        else
          {:cont, next(context, number, target, rows, {before, last})}
        end
      end)

    Enum.reverse(rows)
  end

  defp next(context, 1, target, _rows, found) do
    {row, _start} = harmonic(context, 1, target)
    {[row], found}
  end

  defp next(context, number, target, rows, {_before, last}) do
    {row, start} = harmonic(context, number, target)
    loudest = Enum.max([start | Enum.map(rows, & &1.level)])

    if start > context.floor + 10 and start > loudest - 80 do
      {[row | rows], {last, row.freq}}
    else
      {rows, {last, target}}
    end
  end

  # The harmonic nearest the target, and its level in the first spectrum before the filter's loss is added back.
  defp harmonic(context, number, target) do
    %{spectra: [first | _] = spectra, f0: f0, bin: bin, floor: floor} = context
    bins = max(ceil((target - f0 / 4) / bin), 1)..floor((target + f0 / 4) / bin)
    peak = Enum.max_by(bins, &elem(first, &1))
    {position, start} = Signal.refine(first, peak)
    freq = position * bin

    track =
      for spectrum <- spectra, do: Signal.db(Enum.max(for at <- bins, do: elem(spectrum, at)))

    fade = Signal.fade(context.times, track, max(hd(track) - 40, floor + 10))
    level = start + Signal.filter_loss(freq, context.cutoff)
    {%{number: number, freq: freq, level: level, fade: fade}, start}
  end

  # How far the harmonics are stretched sharp: B, where harmonic n sits at n times the fundamental
  # times the square root of 1 + B n².
  defp stretch(harmonics, f0) do
    points =
      for %{number: number, freq: freq} <- Enum.slice(harmonics, 1, 11),
          do: {number * number, (freq / (number * f0)) ** 2 - 1}

    if length(points) > 2, do: Signal.slope(points), else: 0.0
  end
end
