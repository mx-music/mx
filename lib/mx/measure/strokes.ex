defmodule Mx.Measure.Strokes do
  @moduledoc """
  Measures recordings of an instrument played in strokes that run into one another, such as the rubs of a cuíca's stick, so a synth can play a stroke back as it was measured.

  A stroke lies between two dips of the level, each at least 7 dB deep and 40 ms from the next, and is kept when it comes within 22 dB of the loudest moment and lasts 40 ms or more.
  Its ends are where the level comes within 30 dB of its own loudest moment.
  The pitch is followed every 4 ms by the YIN method, between 150 and 1800 Hz, and a moment has a pitch when the method's doubt is 0.25 or less.
  A pitch above 480 Hz is taken an octave down when the octave under it sounds within 22 dB of it.

  The tracks of a stroke are its pitch, the level of each of its first 16 harmonics and the level of its noise, every 8 ms.
  They come from a least-squares fit of 20 harmonics to 14 ms of the sound every 4 ms, at the pitch within 3% of the one followed that fits best, averaged in pairs.
  The noise is what the fits leave of the sound, each fit weighed by its window where several cover a moment.
  Where the pitch moves fast the fit also leaves tone, so the noise is kept 15 dB or more under the moment's level and the rest is given back to the harmonics.
  The pitch is given in cents against the note the stroke settles at, the pitch that half of its energy lies under.
  The levels are in dB under the stroke's loudest step, and a level more than 66 dB down is given as -127, for silence.
  """

  import Bitwise

  alias Mx.{Audio, Signal}

  @hop 0.004
  @step 2
  @pitch_window 0.02
  @lowest 150
  @highest 1800
  @sure 0.15
  @doubt 0.25
  @octave_above 480
  @octave_under -22
  @level_window 0.012
  @tone_window 0.025
  @fit_window 0.014
  @fitted 20
  @kept 16
  @search 0.03
  @top 0.45
  @around 4
  @covered 0.3
  @envelope_window 0.008
  @envelope_hop 0.002
  @dip 7
  @apart 20
  @heard -22
  @trim 30
  @shortest 0.04
  @voiced 5
  @margin 0.002
  @jump 250
  @ring 0.25
  @before_next 0.006
  @rung -56
  @noise_under -15
  @most 4
  @floor -66
  @silent -127

  @doc "The seconds between two steps of a stroke's tracks."
  def step, do: @hop * @step

  @doc "Finds the strokes of a recording and follows its pitch, and returns `{:ok, recording}` for `tracks/3`, or `{:error, message}` naming the file."
  def file(path) when is_binary(path) do
    with {:ok, %{rate: rate, samples: samples}} <- Audio.read(path) do
      case strokes(samples, rate) do
        %{strokes: []} -> {:error, "found no strokes in #{path}"}
        recording -> {:ok, recording}
      end
    end
  end

  @doc """
  Finds the strokes of a sound and follows its pitch.

  Each stroke has the seconds it lasts `from` and `to`, its `level` in dB under the loudest moment, the `note` its second half holds, and `start`, the cents its first moments lie from that note.
  """
  def strokes(samples, rate) when is_list(samples) and is_integer(rate) do
    sound = List.to_tuple(samples)
    frames = frames(sound, rate)

    strokes =
      for segment <- segments(sound, rate),
          pitches = pitches(frames, rate, segment),
          length(pitches) >= @voiced do
        settled = pitches |> Enum.drop(div(length(pitches), 2)) |> Signal.median()
        first = pitches |> Enum.take(3) |> Signal.median()
        Map.merge(segment, %{note: note(settled), start: cents(first, settled)})
      end

    %{rate: rate, sound: sound, frames: List.to_tuple(frames), strokes: strokes}
  end

  @doc """
  The tracks of the stroke at `index` of a recording's strokes, or nil when the stroke has no pitch.

  `alone: true` carries on past the stroke into the ring it leaves, up to 0.25 seconds, the next stroke, or 56 dB under the stroke's loudest moment, with no noise.
  `ignore: {low, high}` leaves out the harmonics between two frequencies, for a steady tone in the recording that is not the instrument's.

  It gives the `note`, the `cents` of each step, the `levels` of each step as 16 harmonics and then the noise, `body`, the steps that are the stroke and not its ring, and `scoop`, the semitones the stroke starts under its note.
  """
  def tracks(%{strokes: strokes} = recording, index, opts \\ [])
      when is_integer(index) and index >= 0 and is_list(opts) do
    stroke = Enum.fetch!(strokes, index)
    following = Enum.at(strokes, index + 1)
    {body, ring} = span(recording, stroke, following, Keyword.get(opts, :alone, false))
    fitted = fit_all(recording, body ++ ring)

    if Enum.any?(fitted, & &1.hz) do
      fitted |> clean(length(body), Keyword.get(opts, :ignore)) |> steps(length(body))
    end
  end

  defp note(hz), do: 69 + 12 * :math.log2(hz / 440)

  defp cents(hz, against), do: 1200 * :math.log2(hz / against)

  defp pitches(frames, rate, %{from: from, to: to}) do
    for %{at: at, hz: hz} <- frames, hz, at / rate >= from, at / rate <= to, do: hz
  end

  # The pitch and level of the sound every 4 ms.
  defp frames(sound, rate) do
    hop = trunc(@hop * rate)
    window = trunc(@pitch_window * rate)
    lags = div(rate, @lowest)
    tone = trunc(@tone_window * rate)
    last = tuple_size(sound) - window - lags

    0..(last - 1)//hop
    |> Stream.map(fn from ->
      at = from + div(window, 2)
      {at, slice(sound, from, window + lags), slice(sound, at - div(tone, 2), tone)}
    end)
    |> Task.async_stream(
      fn {at, frame, around} -> {at, pitch(frame, around, window, lags, rate)} end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, {at, hz}} -> %{at: at, hz: hz, level: level(sound, at, rate)} end)
  end

  defp slice(sound, from, size) when from >= 0 and from + size <= tuple_size(sound) do
    for at <- from..(from + size - 1)//1, do: elem(sound, at)
  end

  defp slice(_sound, _from, _size), do: nil

  defp level(sound, at, rate) do
    half = div(trunc(@level_window * rate), 2)
    from = max(at - half, 0)
    heard = slice(sound, from, min(at + half, tuple_size(sound)) - from)
    :math.sqrt(dot(heard, heard) / length(heard) + 1.0e-16)
  end

  defp pitch(_frame, nil, _window, _lags, _rate), do: nil

  defp pitch(frame, around, window, lags, rate) do
    {lag, doubt} = yin(frame, window, lags, div(rate, @highest))
    hz = rate / lag

    cond do
      doubt > @doubt -> nil
      hz > @octave_above and under?(around, hz, rate) -> voiced(around, hz / 2, rate)
      true -> voiced(around, hz, rate)
    end
  end

  defp under?(around, hz, rate) do
    tone(around, hz / 2, rate) > tone(around, hz, rate) * 10 ** (@octave_under / 20)
  end

  defp voiced(around, hz, rate), do: if(tone(around, hz, rate) > 0, do: hz)

  # The amplitude of a sine at `hz` in the sound, or within 1% of it.
  defp tone(around, hz, rate) do
    size = length(around)
    window = hann(size)
    heard = Enum.zip_with(around, window, &(&1 * &2))

    strongest =
      Enum.max(
        for off <- [-0.01, 0.0, 0.01] do
          turn = 2 * :math.pi() * hz * (1 + off) / rate
          real = project(heard, turn, 0, &:math.cos/1, 0.0)
          imaginary = project(heard, turn, 0, &:math.sin/1, 0.0)
          :math.sqrt(real * real + imaginary * imaginary)
        end
      )

    strongest * 2 / Enum.sum(window)
  end

  defp project([sample | rest], turn, at, wave, sum) do
    project(rest, turn, at + 1, wave, sum + sample * wave.(turn * at))
  end

  defp project([], _turn, _at, _wave, sum), do: sum

  defp hann(size) do
    for at <- 0..(size - 1), do: 0.5 - 0.5 * :math.cos(2 * :math.pi() * at / (size - 1))
  end

  # The lag at which the frame best repeats, by the YIN method, and its doubt there.
  defp yin(frame, window, lags, shortest) do
    held = Enum.take(frame, window)

    {differences, _} =
      Enum.map_reduce(1..lags, tl(frame), fn _lag, shifted ->
        {squares(held, shifted, 0.0), tl(shifted)}
      end)

    {doubts, _} =
      differences
      |> Enum.with_index(1)
      |> Enum.map_reduce(0.0, fn {difference, lag}, sum ->
        {difference * lag / max(sum + difference, 1.0e-12), sum + difference}
      end)

    doubts = List.to_tuple([1.0 | doubts])
    searched = shortest..(lags - 1)

    lag =
      Enum.find(searched, fn lag ->
        elem(doubts, lag) < @sure and elem(doubts, lag) <= elem(doubts, lag + 1)
      end) || Enum.min_by(searched, &elem(doubts, &1))

    {lag + vertex(elem(doubts, lag - 1), elem(doubts, lag), elem(doubts, lag + 1)),
     elem(doubts, lag)}
  end

  defp vertex(before, at, later) do
    bend = before - 2 * at + later
    if abs(bend) > 1.0e-12, do: 0.5 * (before - later) / bend, else: 0.0
  end

  defp squares([one | ones], [other | others], sum) do
    squares(ones, others, sum + (one - other) * (one - other))
  end

  defp squares([], _others, sum), do: sum

  defp dot([one | ones], [other | others]), do: one * other + dot(ones, others)
  defp dot([], _others), do: 0.0
  defp dot(_ones, []), do: 0.0

  # The stretches between dips of the level that hold a stroke.
  defp segments(sound, rate) do
    size = trunc(@envelope_window * rate)
    hop = trunc(@envelope_hop * rate)
    count = div(tuple_size(sound) - size, hop)

    levels =
      for frame <- 0..(count - 1)//1 do
        heard = slice(sound, frame * hop, size)
        :math.sqrt(dot(heard, heard) / size)
      end

    loudest = Enum.max(levels, fn -> 0.0 end)

    if loudest < 1.0e-5 do
      []
    else
      smooth = levels |> Enum.map(&(20 * :math.log10(&1 / loudest + 1.0e-6))) |> smooth()
      bounds = [0] ++ dips(smooth) ++ [tuple_size(smooth) - 1]
      seconds = fn frame -> (frame * hop + size / 2) / rate end

      for [low, high] <- Enum.chunk_every(bounds, 2, 1, :discard),
          high > low,
          between = Enum.map(low..(high - 1), &{&1, elem(smooth, &1)}),
          {_frame, peak} = Enum.max_by(between, &elem(&1, 1)),
          peak >= @heard,
          inside =
            between
            |> Enum.filter(fn {_, level} -> level > peak - @trim end)
            |> Enum.map(&elem(&1, 0)),
          from = seconds.(hd(inside)),
          to = seconds.(List.last(inside)),
          to - from >= @shortest do
        %{from: from, to: to, level: peak}
      end
    end
  end

  defp smooth(levels) do
    padded = [0.0, 0.0] ++ levels ++ [0.0, 0.0]

    padded
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.map(fn [a, b, c, d, e] -> (0.25 * a + 0.75 * b + c + 0.75 * d + 0.25 * e) / 3 end)
    |> List.to_tuple()
  end

  # The frames where the level dips at least 7 dB under what surrounds it, 20 frames or more apart.
  defp dips(smooth) do
    last = tuple_size(smooth) - 1

    lows =
      for frame <- 1..(last - 1)//1,
          elem(smooth, frame) < elem(smooth, frame - 1),
          elem(smooth, frame) <= elem(smooth, frame + 1),
          do: frame

    lows
    |> Enum.sort_by(&elem(smooth, &1))
    |> Enum.reduce([], fn frame, kept ->
      if Enum.all?(kept, &(abs(&1 - frame) >= @apart)), do: [frame | kept], else: kept
    end)
    |> Enum.filter(fn frame ->
      level = elem(smooth, frame)
      min(rise(smooth, frame, -1, level), rise(smooth, frame, 1, level)) - level >= @dip
    end)
    |> Enum.sort()
  end

  # The highest level on one side of a dip before the level falls under the dip's.
  defp rise(smooth, frame, way, level, highest \\ nil) do
    next = frame + way

    if next < 0 or next >= tuple_size(smooth) or elem(smooth, next) < level do
      highest || level
    else
      rise(smooth, next, way, level, max(highest || level, elem(smooth, next)))
    end
  end

  # The frames of a stroke, and those of the ring after it when it was played alone.
  defp span(%{frames: frames, rate: rate}, stroke, following, alone) do
    count = tuple_size(frames)
    seconds = fn index -> elem(frames, index).at / rate end

    body =
      for index <- 0..(count - 1),
          seconds.(index) >= stroke.from - @margin,
          seconds.(index) <= stroke.to + @margin,
          do: index

    if alone and body != [] do
      next = if following, do: following.from - @before_next, else: seconds.(count - 1)
      stop = min(next, stroke.to + @ring)
      loudest = body |> Enum.map(&elem(frames, &1).level) |> Enum.max()
      quiet = loudest * 10 ** (@rung / 20)

      ring =
        (List.last(body) + 1)..(count - 1)//1
        |> Enum.take_while(&(seconds.(&1) <= stop and elem(frames, &1).level >= quiet))

      {body, ring}
    else
      {body, []}
    end
  end

  defp fit_all(%{frames: frames, sound: sound, rate: rate}, indices) do
    size = trunc(@fit_window * rate) ||| 1
    half = div(size, 2)
    window = hann(size)
    wanted = hd(indices)..List.last(indices)
    fitted = max(wanted.first - @around, 0)..min(wanted.last + @around, tuple_size(frames) - 1)

    fits =
      fitted
      |> Stream.map(fn index ->
        frame = elem(frames, index)
        {frame, frame.hz && slice(sound, frame.at - half, size)}
      end)
      |> Task.async_stream(fn {frame, heard} -> fit(frame, heard, window, rate) end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, fit} -> fit end)

    modelled = modelled(fits, window, half)

    for {fit, index} <- Enum.zip(fits, fitted), index in wanted do
      fit |> Map.delete(:wave) |> Map.put(:noise, noise(sound, modelled, fit.at, rate))
    end
  end

  # The fits that cover each sample, summed, with the sum of their windows.
  defp modelled(fits, window, half) do
    for %{wave: wave, at: at} <- fits,
        wave,
        {value, weight, offset} <- Enum.zip([wave, window, 0..(2 * half)]),
        reduce: %{} do
      sums ->
        Map.update(sums, at - half + offset, {value, weight}, fn {values, weights} ->
          {values + value, weights + weight}
        end)
    end
  end

  # The level of what the fits leave of the sound around a frame.
  defp noise(sound, modelled, at, rate) do
    half = div(trunc(@level_window * rate), 2)

    left =
      for sample <- max(at - half, 0)..(min(at + half, tuple_size(sound)) - 1) do
        case modelled do
          %{^sample => {values, weights}} when weights > @covered ->
            elem(sound, sample) - values / weights

          _ ->
            elem(sound, sample)
        end
      end

    :math.sqrt(dot(left, left) / length(left) + 1.0e-16)
  end

  defp fit(frame, nil, _window, _rate) do
    %{at: frame.at, hz: nil, harmonics: nil, wave: nil, level: frame.level}
  end

  # The harmonics that best fit the sound around a frame, at the pitch within 3% of the one followed that leaves least.
  defp fit(frame, heard, window, rate) do
    weighted = Enum.zip_with(heard, window, &(&1 * &2))

    {_left, hz, harmonics, found, columns} =
      for step <- -6..6 do
        hz = frame.hz * (1 + step * @search / 6)
        {left, harmonics, found, columns} = fit_at(weighted, window, hz, rate)
        {left, hz, harmonics, found, columns}
      end
      |> Enum.min_by(&elem(&1, 0))

    wave =
      [found, columns]
      |> Enum.zip_with(fn [level, column] -> Enum.map(column, &(&1 * level)) end)
      |> Enum.zip_with(&Enum.sum/1)

    %{at: frame.at, hz: hz, harmonics: harmonics, wave: wave, level: frame.level}
  end

  defp fit_at(weighted, window, hz, rate) do
    count = min(@fitted, ceil(@top * rate / hz) - 1)
    half = div(length(window), 2)

    columns =
      for wave <- [&:math.cos/1, &:math.sin/1], harmonic <- 1..count do
        turn = 2 * :math.pi() * harmonic * hz / rate
        Enum.with_index(window, fn weight, at -> weight * wave.(turn * (at - half)) end)
      end

    projected = Enum.map(columns, &dot(&1, weighted))

    upper =
      columns
      |> Enum.with_index()
      |> Enum.map(fn {column, row} ->
        columns |> Enum.drop(row) |> Enum.map(&dot(column, &1)) |> List.to_tuple()
      end)
      |> List.to_tuple()

    all = 2 * count

    rows =
      for {target, row} <- Enum.with_index(projected) do
        for other <- 0..(all - 1) do
          {low, high} = {min(row, other), max(row, other)}
          upper |> elem(low) |> elem(high - low)
        end ++ [target]
      end

    found = solve(rows)
    {cosines, sines} = Enum.split(found, count)
    amplitudes = Enum.zip_with(cosines, sines, &:math.sqrt(&1 * &1 + &2 * &2))
    harmonics = amplitudes ++ List.duplicate(0.0, @fitted - count)
    {-dot(found, projected), harmonics, found, columns}
  end

  # Gaussian elimination, each row its coefficients and then its target.
  defp solve([]), do: []

  defp solve(rows) do
    [[lead | tail] | rest] = Enum.sort_by(rows, &(-abs(hd(&1))))

    reduced =
      for [first | others] <- rest do
        factor = first / lead
        Enum.zip_with(others, tail, &(&1 - factor * &2))
      end

    solved = solve(reduced)
    {coefficients, [target]} = Enum.split(tail, -1)
    [(target - dot(coefficients, solved)) / lead | solved]
  end

  # The frames of one stroke as a pitch, harmonics and noise at every frame, against its loudest frame.
  defp clean(fitted, body, ignore) do
    count = length(fitted)
    kept = fitted |> Enum.map(& &1.hz) |> List.to_tuple() |> same_stroke(body)
    known = for {frame, index} <- Enum.with_index(fitted), index in kept, do: {index, frame}
    {first, _} = hd(known)
    {last, _} = List.last(known)
    pitches = fill(Enum.map(known, fn {index, frame} -> {index, frame.hz} end), count)

    harmonics =
      for harmonic <- 0..(@kept - 1) do
        known
        |> Enum.map(fn {index, frame} ->
          {index, :math.log(max(Enum.at(frame.harmonics, harmonic), 1.0e-7))}
        end)
        |> fill(count)
        |> Enum.map(&:math.exp/1)
      end
      |> Enum.zip_with(& &1)

    frames =
      [fitted, pitches, harmonics]
      |> Enum.zip_with(fn [%{level: level, noise: noise}, hz, harmonics] ->
        %{level: level, noise: noise, hz: hz, harmonics: harmonics}
      end)
      |> Enum.with_index(fn frame, index ->
        outside = if index < first or index > last, do: outside(frame), else: frame
        outside |> toned() |> without(ignore)
      end)

    settled = settled(frames)
    loudest = frames |> Enum.map(&sounding(&1.harmonics)) |> Enum.max()

    for frame <- frames do
      %{
        cents: cents(frame.hz, settled),
        harmonics: Enum.map(frame.harmonics, &(&1 / loudest)),
        noise: frame.noise / loudest
      }
    end
    |> then(&%{hz: settled, frames: &1})
  end

  # The frames that have a pitch, out from the middle of the stroke until the pitch jumps to a neighbouring stroke's.
  defp same_stroke(pitches, body) do
    voiced = for index <- 0..(tuple_size(pitches) - 1), elem(pitches, index), do: index
    middle = Enum.min_by(voiced, &abs(&1 - div(body, 2)))
    later = Enum.filter(voiced, &(&1 > middle))
    earlier = voiced |> Enum.filter(&(&1 < middle)) |> Enum.reverse()
    [middle] ++ walk(later, middle, pitches) ++ walk(earlier, middle, pitches)
  end

  defp walk([index | rest], last, pitches) do
    moved = abs(cents(elem(pitches, index), elem(pitches, last)))

    if moved > @jump * max(1, abs(index - last)) do
      []
    else
      [index | walk(rest, index, pitches)]
    end
  end

  defp walk([], _last, _pitches), do: []

  defp fill(known, count) do
    known = Enum.sort(known)
    for at <- 0..(count - 1), do: between(known, at)
  end

  defp between([{first, value} | _], at) when at <= first, do: value

  defp between([{low, one}, {high, other} | _], at) when at <= high do
    one + (other - one) * (at - low) / (high - low)
  end

  defp between([{_, value}], _at), do: value
  defp between([_ | rest], at), do: between(rest, at)

  # The level of a sound made of harmonics of these amplitudes.
  defp sounding(harmonics), do: :math.sqrt(dot(harmonics, harmonics) / 2)

  # Past the first and last frame with a pitch, the harmonics are the nearest ones, no louder than the sound.
  defp outside(%{harmonics: harmonics, level: level} = frame) do
    gain = min(1, level / max(sounding(harmonics), 1.0e-9))
    %{frame | harmonics: Enum.map(harmonics, &(&1 * gain))}
  end

  # The noise is kept 15 dB under the frame's level, and the harmonics raised to the rest of it, by 12 dB at most.
  defp toned(%{harmonics: harmonics, level: level, noise: noise} = frame) do
    noise = min(noise, level * 10 ** (@noise_under / 20))
    rest = :math.sqrt(max(level * level - noise * noise, 0.0))
    gain = max(1, min(rest / max(sounding(harmonics), 1.0e-9), @most))
    %{frame | noise: noise, harmonics: Enum.map(harmonics, &(&1 * gain))}
  end

  defp without(frame, nil), do: frame

  defp without(%{harmonics: harmonics, hz: hz} = frame, {low, high}) do
    kept =
      Enum.with_index(harmonics, fn level, index ->
        if hz * (index + 1) > low and hz * (index + 1) < high, do: 0.0, else: level
      end)

    %{frame | harmonics: kept}
  end

  # The pitch that half of the stroke's energy lies under.
  defp settled(frames) do
    weighed =
      frames |> Enum.map(&{&1.hz, sounding(&1.harmonics) ** 2}) |> Enum.sort()

    half = (weighed |> Enum.map(&elem(&1, 1)) |> Enum.sum()) / 2

    Enum.reduce_while(weighed, 0.0, fn {hz, weight}, under ->
      if under + weight >= half, do: {:halt, hz}, else: {:cont, under + weight}
    end)
  end

  defp steps(%{hz: hz, frames: frames}, body) do
    pairs = Enum.chunk_every(frames, @step, @step, :discard)
    ends = [Enum.take(frames, 2), Enum.slice(frames, max(body - 2, 0), 2)]
    [early, late] = Enum.map(ends, &mean_cents/1)
    body = div(body, @step)
    mean_square = fn values -> :math.sqrt(dot(values, values) / length(values)) end

    steps =
      for pair <- pairs do
        %{
          cents: round(Enum.sum(Enum.map(pair, & &1.cents)) / @step),
          harmonics: pair |> Enum.map(& &1.harmonics) |> Enum.zip_with(mean_square),
          noise: mean_square.(Enum.map(pair, & &1.noise))
        }
      end

    loudest = steps |> Enum.map(&sounding(&1.harmonics)) |> Enum.max()

    levels =
      Enum.with_index(steps, fn step, index ->
        noise = if index < body, do: step.noise, else: 0.0
        Enum.map(step.harmonics ++ [noise], &quantise(&1 / loudest))
      end)

    cents = Enum.map(steps, & &1.cents)

    %{
      note: note(hz),
      body: body,
      scoop: -early / 100,
      ends: late / 100,
      cents: cents,
      levels: levels
    }
  end

  defp mean_cents(frames), do: Enum.sum(Enum.map(frames, & &1.cents)) / length(frames)

  defp quantise(level) do
    db = round(20 * :math.log10(max(level, 1.0e-7)))
    if db < @floor, do: @silent, else: min(db, 0)
  end
end
