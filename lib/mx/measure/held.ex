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

  alias Mx.Signal

  @hop 0.01
  @lead 0.05
  @held_range 12
  @reach 0.5

  @doc "Measures each held note of a recording that starts on `note`, and returns `{:ok, notes}` or `{:error, message}` naming the file."
  def file(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_file(path, "notes", &notes(&1, &2, note))
  end

  @doc "Measures a recording as one note on `note` held from its first sample to its last, such as a drone plucked again and again, and returns `{:ok, [note]}` or `{:error, message}` naming the file."
  def drone(path, note) when is_binary(path) and is_integer(note) do
    Signal.measure_file(path, "drone", &List.wrap(note(&1, &2, note)))
  end

  @doc "Measures each held note of a sound whose first note is `first`, one after another a semitone apart."
  def notes(samples, rate, first)
      when is_list(samples) and is_integer(rate) and is_integer(first) do
    cutoff = Signal.hz(first) * 0.75
    filtered = Signal.high_pass(samples, rate, cutoff)
    sound = List.to_tuple(filtered)
    starts = Signal.onsets(filtered, rate, 1)
    ends = Enum.drop(starts, 1) ++ [tuple_size(sound)]
    lead = round(@lead * rate)

    Enum.zip(starts, ends)
    |> Enum.with_index(fn {from, to}, index ->
      silence = List.duplicate(0.0, max(lead - from, 0))
      held = for at <- max(from - lead, 0)..(to - 1)//1, do: elem(sound, at)
      segment = silence ++ held
      {segment, first + index}
    end)
    |> Task.async_stream(fn {segment, guess} -> measure(segment, rate, guess, cutoff) end,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
  end

  @doc "Measures a sound that is one held note from its first sample, such as a synth rendered offline, or returns nil when it is too short."
  def note(samples, rate, note) when is_list(samples) and is_integer(rate) and is_integer(note) do
    cutoff = Signal.hz(note) * 0.75
    silence = List.duplicate(0.0, round(@lead * rate))
    measure(silence ++ Signal.high_pass(samples, rate, cutoff), rate, note, cutoff)
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

  defp measure(segment, rate, guess, cutoff) do
    sound = List.to_tuple(segment)
    small = window(rate, 0.043)
    large = window(rate, 0.17)
    hop = round(@hop * rate)
    starts = Enum.to_list(0..(tuple_size(sound) - large)//hop)

    if length(starts) < 40 do
      nil
    else
      energies =
        for from <- starts,
            do: energy(Signal.spectrum(sound, from + div(large - small, 2), small))

      held = held(starts, energies)
      inside = inside(held, div(large - small, 2))
      spectra = for from <- Enum.take_every(inside, 5), do: Signal.spectrum(sound, from, large)
      bin = rate / large
      f0 = pitch(spectra, Signal.hz(guess), bin)
      harmonics = harmonics(spectra, f0, bin, rate, cutoff)
      centre = div(large, 2)

      %{
        note: round(69 + 12 * :math.log2(f0 / 440)),
        pitch: f0,
        held: length(held) * @hop,
        attack: attack(segment, rate, held, centre),
        vibrato: vibrato(sound, held, f0, harmonics, rate, centre),
        harmonics: harmonics,
        noise: noise(spectra, f0, bin, rate, cutoff)
      }
    end
  end

  # The power of two nearest the given seconds.
  defp window(rate, seconds), do: 2 ** round(:math.log2(seconds * rate))

  defp energy(spectrum) do
    power = Enum.sum(for magnitude <- Tuple.to_list(spectrum), do: magnitude * magnitude)
    10 * :math.log10(power + 1.0e-24)
  end

  # The frame starts of the longest stretch within 12 dB of the loudest.
  defp held(starts, energies) do
    loudest = Enum.max(energies)

    starts
    |> Enum.zip(energies)
    |> Enum.chunk_by(fn {_, energy} -> energy >= loudest - @held_range end)
    |> Enum.filter(fn [{_, energy} | _] -> energy >= loudest - @held_range end)
    |> Enum.max_by(&length/1)
    |> Enum.map(&elem(&1, 0))
  end

  # The held frames whose large window lies wholly within the held part.
  # A sound cut off right after the held part then leaks into no spectrum.
  defp inside(held, trim) do
    first = hd(held) + trim
    last = List.last(held) - trim

    case Enum.filter(held, &(&1 >= first and &1 <= last)) do
      [] -> held
      inside -> inside
    end
  end

  # The fundamental within 6% of the guess whose first six harmonics hold the most energy, over the held spectra.
  defp pitch(spectra, guess, bin) do
    steps = round(guess * 0.12 / 0.05)

    0..steps
    |> Enum.map(&(guess * 0.94 + &1 * 0.05))
    |> Enum.max_by(fn freq ->
      Enum.sum(
        for spectrum <- spectra,
            number <- 1..6,
            do: Signal.magnitude_at(spectrum, freq * number / bin)
      )
    end)
  end

  # Each harmonic's frequency and level, averaged in power over the held spectra.
  # A harmonic less than 10 dB above the floor, or 80 dB below the loudest, is absent.
  defp harmonics(spectra, f0, bin, rate, cutoff) do
    floor =
      spectra |> mean_power() |> Enum.map(&(10 * :math.log10(&1 + 1.0e-24))) |> Signal.median()

    top = min(18_000, rate / 2 - f0)
    count = floor(top / f0)

    found =
      for number <- 1..count//1 do
        target = number * f0
        bins = max(ceil((target - f0 / 4) / bin), 1)..floor((target + f0 / 4) / bin)

        peaks =
          for spectrum <- spectra do
            peak(spectrum, bins)
          end

        freq = Enum.sum(for {position, _} <- peaks, do: position) / length(peaks) * bin
        level = power_mean(for {_, level} <- peaks, do: level)
        %{number: number, freq: freq, level: level + Signal.filter_loss(freq, cutoff), raw: level}
      end

    loudest = found |> Enum.map(& &1.raw) |> Enum.max()

    for %{raw: raw} = harmonic <- found, raw > floor + 10 and raw > loudest - 80 do
      Map.delete(harmonic, :raw)
    end
  end

  # The loudest bin's position and level, refined between bins only when it is louder than both its neighbours.
  defp peak(spectrum, bins) do
    peak = Enum.max_by(bins, &elem(spectrum, &1))
    level = elem(spectrum, peak)

    if level > elem(spectrum, peak - 1) and level >= elem(spectrum, peak + 1) do
      Signal.refine(spectrum, peak)
    else
      {peak * 1.0, Signal.db(level)}
    end
  end

  defp mean_power(spectra) do
    count = length(spectra)

    spectra
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.zip_with(fn magnitudes ->
      Enum.sum(for magnitude <- magnitudes, do: magnitude * magnitude) / count
    end)
  end

  defp power_mean(levels) do
    mean = Enum.sum(for level <- levels, do: 10 ** (level / 10)) / length(levels)
    10 * :math.log10(mean)
  end

  # The power between the harmonics in each band above the high-pass.
  # It is given as the level in dB of a harmonic of the same power.
  # A Hann window gives a harmonic of amplitude A a peak of A N / 4.
  # It gives white noise of variance σ² a power of 3 N σ² / 8 in each bin.
  defp noise(spectra, f0, bin, rate, cutoff) do
    size = tuple_size(hd(spectra)) * 2
    powers = mean_power(spectra) |> List.to_tuple()

    for {low, high} = band <- Signal.bands(),
        low >= cutoff,
        high <= rate / 2,
        between = between(low, high, f0, bin, tuple_size(powers)),
        between != [] do
      mean =
        Enum.sum(
          for at <- between,
              do: elem(powers, at) * 10 ** (Signal.filter_loss(at * bin, cutoff) / 10)
        ) /
          length(between)

      variance = mean / (3 * size / 8)
      power = variance * (high - low) / (rate / 2)
      %{band: band, level: 10 * :math.log10(2 * power + 1.0e-24) + Signal.db(size / 4)}
    end
  end

  # The bins of a band in the middle third between two harmonics.
  defp between(low, high, f0, bin, count) do
    for at <- ceil(low / bin)..min(floor(high / bin), count - 1)//1,
        place = at * bin / f0,
        place > 1,
        offset = place - floor(place),
        offset >= 1 / 3 and offset <= 2 / 3,
        do: at
  end

  # The seconds from where the sound starts, 40 dB below its held level, until it first comes within 0.5 dB of it.
  defp attack(segment, rate, held, centre) do
    window = round(0.01 * rate)
    step = round(0.001 * rate)
    sound = List.to_tuple(segment)

    envelope =
      for from <- 0..(tuple_size(sound) - window)//step do
        sum = Enum.sum(for at <- from..(from + window - 1), do: elem(sound, at) ** 2)
        {(from + window / 2) / rate, :math.sqrt(sum / window)}
      end

    first = (hd(held) + centre) / rate
    last = (List.last(held) + centre) / rate

    level =
      Signal.median(for {time, value} <- envelope, time >= first and time <= last, do: value)

    reached = Enum.find(envelope, fn {_, value} -> value >= level * 10 ** (-@reach / 20) end)
    {reach_time, _} = reached

    start =
      envelope
      |> Enum.take_while(&(&1 != reached))
      |> Enum.filter(fn {_, value} -> value < level / 100 end)
      |> List.last({0.0, 0.0})
      |> elem(0)

    reach_time - start
  end

  # The pitch of the strongest of the first four harmonics in short frames across the held part, in cents.
  # The frames average the swing over their length.
  # So the depth is divided by what a Hann window keeps of a swing at that rate.
  defp vibrato(sound, held, f0, harmonics, rate, centre) do
    small = window(rate, 0.043)
    bin = rate / small

    strongest =
      harmonics
      |> Enum.filter(&(&1.number <= 4))
      |> Enum.max_by(& &1.level, fn -> %{number: 1} end)

    number = strongest.number
    target = number * f0

    track =
      for from <- held do
        spectrum = Signal.spectrum(sound, from + centre - div(small, 2), small)
        bins = max(floor(target * 0.94 / bin), 1)..ceil(target * 1.06 / bin)
        {position, _} = peak(spectrum, bins)
        1200 * :math.log2(position * bin / target)
      end

    swing(track, small / rate)
  end

  defp swing(track, frame) when length(track) >= 60 do
    times = Enum.with_index(track, fn _, index -> index * @hop end)
    slope = Signal.slope(Enum.zip(times, track))
    mean = Enum.sum(track) / length(track)
    middle = Enum.sum(times) / length(times)

    deviations =
      Enum.zip_with(times, track, fn time, cents -> cents - mean - slope * (time - middle) end)

    {lag, correlation} =
      10..33
      |> Enum.map(&{&1, correlation(deviations, &1)})
      |> Enum.max_by(&elem(&1, 1))

    rms =
      :math.sqrt(
        Enum.sum(for deviation <- deviations, do: deviation * deviation) / length(deviations)
      )

    lag = refine_lag(deviations, lag)
    vibrato_rate = 1 / (lag * @hop)
    depth = rms * :math.sqrt(2) / kept(vibrato_rate, frame)

    if correlation >= 0.5 and depth >= 5, do: %{rate: vibrato_rate, depth: depth}
  end

  defp swing(_track, _frame), do: nil

  defp correlation(values, lag) do
    count = length(values)
    products = Enum.zip_with(values, Enum.drop(values, lag), &(&1 * &2))
    power = Enum.sum(for value <- values, do: value * value)
    if power > 0, do: Enum.sum(products) / power * count / (count - lag), else: 0.0
  end

  defp refine_lag(values, lag) do
    [left, top, right] = for at <- (lag - 1)..(lag + 1), do: correlation(values, at)
    curve = left - 2 * top + right
    if curve < 0, do: lag + 0.5 * (left - right) / curve, else: lag * 1.0
  end

  # What a Hann window of `frame` seconds keeps of a sine swing at `rate` times a second.
  defp kept(rate, frame) do
    count = 256

    weights =
      for index <- 0..(count - 1), do: 0.5 - 0.5 * :math.cos(2 * :math.pi() * index / count)

    phases = for index <- 0..(count - 1), do: 2 * :math.pi() * rate * frame * index / count
    real = Enum.sum(Enum.zip_with(weights, phases, &(&1 * :math.cos(&2))))
    imaginary = Enum.sum(Enum.zip_with(weights, phases, &(&1 * :math.sin(&2))))
    :math.sqrt(real * real + imaginary * imaginary) / Enum.sum(weights)
  end
end
