defmodule Mx.Signal do
  @moduledoc """
  The pieces the measuring of plucked notes, held notes and hits share: filtering, spectra, finding where sounds start, and fitting a fade.

  Levels are in dB, and a spectrum is a tuple of the magnitudes of its frequency bins.
  """

  alias Mx.{Audio, FFT}

  @bands [
    {80, 160},
    {160, 250},
    {250, 400},
    {400, 630},
    {630, 1000},
    {1000, 1600},
    {1600, 2500},
    {2500, 4000},
    {4000, 6300},
    {6300, 10_000},
    {10_000, 16_000}
  ]

  @onset_hop 0.005
  @onset_window 40

  @doc "The frequency bands measurements are given in, each a third of an octave or wider, as `{low, high}` in Hz."
  def bands, do: @bands

  @doc "Reads a recording and measures its samples and rate with `measure`, and returns `{:ok, found}`, or `{:error, message}` naming the file when it is refused or `measure` finds nothing."
  def measure_file(path, what, measure)
      when is_binary(path) and is_binary(what) and is_function(measure, 2) do
    with {:ok, %{rate: rate, samples: samples}} <- Audio.read(path) do
      case measure.(samples, rate) do
        [] -> {:error, "found no #{what} in #{path}"}
        found -> {:ok, found}
      end
    end
  end

  @doc "The frequency of a note number."
  def hz(note) when is_number(note), do: 440 * 2 ** ((note - 69) / 12)

  @doc "A level in dB for a magnitude."
  def db(magnitude) when is_number(magnitude), do: 20 * :math.log10(magnitude + 1.0e-12)

  @doc "The middle value of a list of numbers, or the mean of the two middle ones."
  def median(values) when is_list(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle)
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  @doc "The spectrum of `size` samples of a sound, given as a tuple, from the sample `from`."
  def spectrum(sound, from, size)
      when is_tuple(sound) and is_integer(from) and is_integer(size) do
    frame = for at <- from..(from + size - 1), do: elem(sound, at)
    frame |> FFT.magnitudes() |> List.to_tuple()
  end

  @doc "The magnitude of a spectrum at a position between bins, by a straight line between the two bins around it."
  def magnitude_at(spectrum, position) when is_tuple(spectrum) and is_number(position) do
    below = floor(position)

    if below + 1 < tuple_size(spectrum) do
      low = elem(spectrum, below)
      low + (position - below) * (elem(spectrum, below + 1) - low)
    else
      0.0
    end
  end

  @doc "A peak's position between bins and its level in dB, from a parabola through the log magnitudes around it."
  def refine(spectrum, peak) when is_tuple(spectrum) and is_integer(peak) do
    [left, top, right] = for at <- (peak - 1)..(peak + 1), do: db(elem(spectrum, at))
    curve = left - 2 * top + right

    if curve < 0 do
      shift = 0.5 * (left - right) / curve
      {peak + shift, top - 0.25 * (left - right) * shift}
    else
      {peak * 1.0, top}
    end
  end

  @doc "The seconds a level takes to fade 60 dB, from a straight line through the levels above `above`, or nil when it does not fade."
  def fade(times, track, above) when is_list(times) and is_list(track) and is_number(above) do
    points = for {time, level} <- Enum.zip(times, track), level > above, do: {time, level}

    if length(points) > 3 do
      slope = slope(points)
      if slope < 0, do: -60 / slope
    end
  end

  @doc "The slope of the straight line that best fits a list of `{x, y}` points."
  def slope(points) when is_list(points) do
    count = length(points)
    mean_x = Enum.sum(Enum.map(points, &elem(&1, 0))) / count
    mean_y = Enum.sum(Enum.map(points, &elem(&1, 1))) / count

    covariance =
      Enum.sum(for {x_value, y_value} <- points, do: (x_value - mean_x) * (y_value - mean_y))

    variance = Enum.sum(for {x_value, _} <- points, do: (x_value - mean_x) ** 2)
    covariance / variance
  end

  @doc """
  The sample each sound starts at: a 5 ms level within 30 dB of the loudest, and 20 dB above the quietest of the 40 before it, at least `gap` seconds after the start before it.
  """
  def onsets(samples, rate, gap) when is_list(samples) and is_integer(rate) and is_number(gap) do
    hop = round(rate * @onset_hop)

    levels =
      for chunk <- Enum.chunk_every(samples, hop),
          do: :math.sqrt(Enum.sum(Enum.map(chunk, &(&1 * &1))) / hop)

    loudest = Enum.max(levels, fn -> 0.0 end)

    if loudest < 1.0e-5 do
      []
    else
      dbs =
        List.to_tuple(
          List.duplicate(-120.0, @onset_window) ++ Enum.map(levels, &db(&1 / loudest))
        )

      frames = gap / @onset_hop

      @onset_window..(tuple_size(dbs) - 1)//1
      |> Enum.reduce([], fn frame, found ->
        if onset?(dbs, frame, found, frames), do: [frame | found], else: found
      end)
      |> Enum.reverse()
      |> Enum.map(&((&1 - @onset_window) * hop))
    end
  end

  defp onset?(dbs, frame, found, frames) do
    level = elem(dbs, frame)
    quietest = Enum.min(for before <- (frame - @onset_window)..(frame - 1), do: elem(dbs, before))
    rises? = level > -30 and level - quietest > 20
    rises? and (found == [] or frame - hd(found) > frames)
  end

  @doc "A fourth-order Butterworth high-pass at `hz`, run forward and then backward so it shifts nothing in time."
  def high_pass(samples, rate, hz) when is_list(samples) and is_integer(rate) and is_number(hz) do
    pass = fn samples -> samples |> biquad(rate, hz, 0.5412) |> biquad(rate, hz, 1.3066) end
    samples |> pass.() |> Enum.reverse() |> pass.() |> Enum.reverse()
  end

  @doc "A fourth-order Butterworth low-pass at `hz`, run forward and then backward so it shifts nothing in time."
  def low_pass(samples, rate, hz) when is_list(samples) and is_integer(rate) and is_number(hz) do
    pass = fn samples ->
      samples |> biquad(rate, hz, 0.5412, :low) |> biquad(rate, hz, 1.3066, :low)
    end

    samples |> pass.() |> Enum.reverse() |> pass.() |> Enum.reverse()
  end

  @doc "What the high-pass, run forward and backward, takes from a frequency, in dB: each run multiplies the amplitude by 1 / √(1 + (cutoff / freq)⁸)."
  def filter_loss(freq, cutoff) when is_number(freq) and is_number(cutoff) do
    20 * :math.log10(1 + (cutoff / freq) ** 8)
  end

  # Robert Bristow-Johnson's high-pass and low-pass biquads: the input and output of the two
  # samples before weigh into each output.
  defp biquad(samples, rate, hz, quality, kind \\ :high) do
    angle = 2 * :math.pi() * hz / rate
    alpha = :math.sin(angle) / (2 * quality)
    cos = :math.cos(angle)
    scale = 1 + alpha

    {outer, middle} =
      case kind do
        :high -> {(1 + cos) / 2 / scale, -(1 + cos) / scale}
        :low -> {(1 - cos) / 2 / scale, (1 - cos) / scale}
      end

    back1 = -2 * cos / scale
    back2 = (1 - alpha) / scale

    {out, _} =
      Enum.map_reduce(samples, {0.0, 0.0, 0.0, 0.0}, fn input, {in1, in2, out1, out2} ->
        output = outer * input + middle * in1 + outer * in2 - back1 * out1 - back2 * out2
        {output, {input, in1, output, out1}}
      end)

    out
  end
end
