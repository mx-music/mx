defmodule Mx.Measure.Hits do
  @moduledoc """
  Measures recordings of hits, struck bars, bells, drums and scrapers, with or without a pitch, so a synth's design can be compared with a real instrument's.

  A file holds one hit or several, one after another, each starting from silence.
  Rumble is filtered out below three quarters of the note given, or below 30 Hz without one, and the bands are measured from there up.
  For each hit it finds the level of each band as the hit starts, against the loudest band, and the seconds each band takes to fade 60 dB.
  It also lists the frequencies of the hit's strongest peaks, up to six within 30 dB of the loudest, as ratios to the lowest of them, so the partials of a bar or a drum show whatever their pitch.
  It also gives each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment, against the loudest band then, nil past the hit's end and -40 for a level more than 40 dB down, and the second the hit starts at in the sound.
  With `partials:` a count, it also lists up to that many of the strongest partials within 40 dB of the loudest, lowest first, each with its frequency in Hz, its ratio to the lowest, its level in dB against the loudest and the seconds it takes to fade 60 dB, or nil when it does not fade; two partials closer than 1% are one.
  """

  alias Mx.Signal

  @hop 0.01
  @longest 4.0
  @peaks 6
  @moments [0, 50, 100, 200]

  @doc "Measures each hit of a recording, with the note it plays or nil, and returns `{:ok, hits}` or `{:error, message}` naming the file."
  def file(path, note, opts \\ [])
      when is_binary(path) and (is_integer(note) or is_nil(note)) and is_list(opts) do
    Signal.measure_file(path, "hits", &hits(&1, &2, note, opts))
  end

  @doc "Measures each hit of a sound, one after another from silence, with the note they play or nil."
  def hits(samples, rate, note, opts \\ [])
      when is_list(samples) and is_integer(rate) and (is_integer(note) or is_nil(note)) and
             is_list(opts) do
    cutoff = cutoff(note)
    filtered = Signal.high_pass(samples, rate, cutoff)
    sound = List.to_tuple(filtered)
    starts = Signal.onsets(filtered, rate, 0.25)
    ends = Enum.drop(starts, 1) ++ [tuple_size(sound)]
    longest = round(@longest * rate)

    starts
    |> Enum.zip(ends)
    |> Enum.map(fn {from, to} ->
      {from / rate, Enum.map(from..(min(to, from + longest) - 1)//1, &elem(sound, &1))}
    end)
    |> Task.async_stream(
      fn {start, segment} -> measure(segment, start, rate, cutoff, opts[:partials]) end,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, hit} -> List.wrap(hit) end)
  end

  @doc "Measures a sound that is one hit from its first sample, such as a synth rendered offline, or returns nil when it is too short."
  def hit(samples, rate, note, opts \\ [])
      when is_list(samples) and is_integer(rate) and (is_integer(note) or is_nil(note)) and
             is_list(opts) do
    cutoff = cutoff(note)

    samples
    |> Signal.high_pass(rate, cutoff)
    |> Enum.take(round(@longest * rate))
    |> measure(0.0, rate, cutoff, opts[:partials])
  end

  @doc "The milliseconds after a hit's loudest moment that `moments` are taken at."
  def moment_times, do: @moments

  @doc "The median level of each band at each moment over the hits, leaving out hits that end before it, or nil when none reaches it."
  def moments(hits) when is_list(hits) do
    found = Enum.flat_map(hits, & &1.moments)

    for band <- Signal.bands(),
        inside = Enum.filter(found, &(&1.band == band)),
        inside != [] do
      levels =
        inside
        |> Enum.map(& &1.levels)
        |> Enum.zip_with(fn levels ->
          case Enum.reject(levels, &is_nil/1) do
            [] -> nil
            reached -> Signal.median(reached)
          end
        end)

      %{band: band, levels: levels}
    end
  end

  @doc "The median level and fade of each band over the hits."
  def summary(hits) when is_list(hits) do
    found = Enum.flat_map(hits, & &1.bands)

    for band <- Signal.bands(),
        inside = Enum.filter(found, &(&1.band == band)),
        inside != [] do
      fades = for %{fade: fade} <- inside, fade != nil, do: fade
      fade = if fades == [], do: nil, else: Signal.median(fades)

      %{
        band: band,
        level: Signal.median(Enum.map(inside, & &1.level)),
        fade: fade,
        count: length(inside)
      }
    end
  end

  defp cutoff(nil), do: 30
  defp cutoff(note), do: Signal.hz(note) * 0.75

  defp measure(segment, start, rate, cutoff, count) do
    sound = List.to_tuple(segment)
    size = 2 ** round(:math.log2(0.043 * rate))
    hop = round(@hop * rate)
    starts = Enum.to_list(0..(tuple_size(sound) - size)//hop)

    if length(starts) < 5 do
      nil
    else
      spectra = for from <- starts, do: Signal.spectrum(sound, from, size)
      times = for from <- starts, do: (from + size / 2) / rate

      tracks = tracks(spectra, rate / size, rate, cutoff)

      %{
        start: start,
        bands: bands(tracks, times),
        moments: track_moments(tracks),
        peaks: peaks(sound, rate, cutoff),
        partials: partials(sound, {spectra, times, rate / size}, rate, cutoff, count)
      }
    end
  end

  # Each band's power in every frame, in dB, from the rumble filter's cutoff up.
  defp tracks(spectra, bin, rate, cutoff) do
    for {low, high} = band <- Signal.bands(),
        high <= rate / 2,
        bins = Enum.to_list(ceil(max(low, cutoff) / bin)..(ceil(high / bin) - 1)//1),
        bins != [] do
      track =
        for spectrum <- spectra do
          power =
            Enum.sum(
              for at <- bins,
                  do: elem(spectrum, at) ** 2 * 10 ** (Signal.filter_loss(at * bin, cutoff) / 10)
            )

          10 * :math.log10(power + 1.0e-24)
        end

      {band, track}
    end
  end

  # A band's level as the hit starts is the loudest of the first three frames.
  # A band less than 10 dB above its own quietest frame, or 60 dB below the loudest band, is left
  # out.
  defp bands(tracks, times) do
    starts = Map.new(tracks, fn {band, track} -> {band, track |> Enum.take(3) |> Enum.max()} end)
    loudest = starts |> Map.values() |> Enum.max()

    for {band, track} <- tracks,
        start = starts[band],
        quietest = Enum.min(track),
        start > quietest + 10 and start > loudest - 60 do
      %{
        band: band,
        level: start - loudest,
        fade: Signal.fade(times, track, max(start - 40, quietest + 10))
      }
    end
  end

  # Each band's level at each moment after the loudest of the first three frames, against the
  # loudest band then.
  # A moment past the hit's last frame is nil, and a level more than 40 dB down is -40.
  defp track_moments(tracks) do
    first =
      tracks |> Enum.map(fn {_band, track} -> Enum.take(track, 3) end) |> Enum.zip_with(& &1)

    power = Enum.map(first, fn levels -> Enum.sum(Enum.map(levels, &(10 ** (&1 / 10)))) end)
    loudest = Enum.find_index(power, &(&1 == Enum.max(power)))
    top = first |> Enum.at(loudest) |> Enum.max()

    for {band, track} <- tracks do
      levels =
        for ms <- @moments do
          level = Enum.at(track, loudest + round(ms / 1000 / @hop))
          level && max(level - top, -40)
        end

      %{band: band, levels: levels}
    end
  end

  # The strongest peaks of a spectrum of the hit's start, each at least 3% and four bins from a
  # stronger one.
  defp peaks(sound, rate, cutoff) do
    {spectrum, levels, loudest, bin} = start_spectrum(sound, rate)

    levels
    |> strongest(loudest - 30, ceil(cutoff / bin), &max(4, 0.03 * &1), @peaks)
    |> Enum.map(fn at -> at |> then(&Signal.refine(spectrum, &1)) |> elem(0) end)
    |> Enum.sort()
    |> then(fn [lowest | _] = positions -> Enum.map(positions, &(&1 / lowest)) end)
  end

  defp partials(_sound, _frames, _rate, _cutoff, nil), do: []

  # Each partial's ring follows the frames' bins around it, as a band's fade follows its bins.
  defp partials(sound, {spectra, times, frame_bin}, rate, cutoff, count) do
    {spectrum, levels, loudest, bin} = start_spectrum(sound, rate)

    found =
      levels
      |> strongest(loudest - 40, ceil(cutoff / bin), &max(3, 0.01 * &1), count)
      |> Enum.map(&Signal.refine(spectrum, &1))
      |> Enum.sort()

    [{lowest, _level} | _] = found
    top = found |> Enum.map(&elem(&1, 1)) |> Enum.max()

    for {position, level} <- found do
      hz = position * bin
      at = round(hz / frame_bin)
      track = for frame <- spectra, do: Signal.db(peak_near(frame, at))
      start = track |> Enum.take(3) |> Enum.max()
      ring = Signal.fade(times, track, max(start - 40, Enum.min(track) + 10))
      %{hz: hz, ratio: position / lowest, level: level - top, ring: ring}
    end
  end

  defp start_spectrum(sound, rate) do
    size = 2 ** min(floor(:math.log2(tuple_size(sound))), round(:math.log2(0.34 * rate)))
    spectrum = Signal.spectrum(sound, 0, size)
    levels = for at <- 0..(tuple_size(spectrum) - 1), do: Signal.db(elem(spectrum, at))
    {spectrum, List.to_tuple(levels), Enum.max(levels), rate / size}
  end

  # The bins of the loudest local peaks above `floor`, from `first` up, each apart from a stronger
  # one kept.
  defp strongest(levels, floor, first, apart, count) do
    max(first, 1)..(tuple_size(levels) - 2)//1
    |> Enum.filter(fn at ->
      level = elem(levels, at)
      level > floor and level > elem(levels, at - 1) and level >= elem(levels, at + 1)
    end)
    |> Enum.sort_by(&elem(levels, &1), :desc)
    |> Enum.reduce([], fn at, kept ->
      apart? = Enum.all?(kept, fn other -> abs(at - other) > apart.(other) end)
      if apart? and length(kept) < count, do: [at | kept], else: kept
    end)
  end

  defp peak_near(frame, at) do
    Enum.max(
      for near <- max(at - 1, 0)..min(at + 1, tuple_size(frame) - 1), do: elem(frame, near)
    )
  end
end
