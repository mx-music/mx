defmodule Mx.Signal do
  @moduledoc """
  The pieces the measuring of plucked notes, held notes and hits share in Elixir: reading a recording for the native measuring, spectra, the bands and a high-pass.

  Levels are in dB, and a spectrum is a tuple of the magnitudes of its frequency bins.
  """

  alias Mx.Audio
  alias Mx.Engine.Mxs.Native

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

  @doc "The frequency bands measurements are given in, each a third of an octave or wider, as `{low, high}` in Hz."
  def bands, do: @bands

  @doc "Reads a recording without decoding it and measures it with `measure`, given its data, its `{kind, bits, channels}` and its rate, and returns `{:ok, found}`, or `{:error, message}` naming the file when it is refused or `measure` finds nothing."
  def measure_data(path, what, measure)
      when is_binary(path) and is_binary(what) and is_function(measure, 3) do
    with {:ok, %{rate: rate} = format, data} <- Audio.raw(path) do
      case measure.(data, native(format), rate / 1) do
        [] -> {:error, "found no #{what} in #{path}"}
        found -> {:ok, found}
      end
    end
  end

  @doc "Samples from -1 to 1 as data the native measuring reads, with its `{kind, bits, channels}`."
  def packed(samples) when is_list(samples) do
    data = for sample <- samples, into: <<>>, do: <<sample / 1::float-little-64>>
    {data, {"float_little", 64, 1}}
  end

  @doc "The format of `Mx.Audio.raw/1`'s data as the native measuring takes it, `{kind, bits, channels}`."
  def native(%{kind: kind, bits: bits, channels: channels}) do
    {Atom.to_string(kind), bits, channels}
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
      below = Enum.at(sorted, middle - 1)
      above = Enum.at(sorted, middle)
      (below + above) / 2
    end
  end

  @doc "The spectrum of `size` samples of a sound, given as a tuple, from the sample `from`."
  def spectrum(sound, from, size)
      when is_tuple(sound) and is_integer(from) and is_integer(size) do
    {data, format} = packed(for at <- from..(from + size - 1), do: elem(sound, at))
    data |> Native.spectrum(format, 0, size) |> List.to_tuple()
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

  @doc "A fourth-order Butterworth high-pass at `hz`, run forward and then backward so it shifts nothing in time."
  def high_pass(samples, rate, hz) when is_list(samples) and is_integer(rate) and is_number(hz) do
    pass = fn samples -> samples |> biquad(rate, hz, 0.5412) |> biquad(rate, hz, 1.3066) end
    samples |> pass.() |> Enum.reverse() |> pass.() |> Enum.reverse()
  end

  @doc "What the high-pass, run forward and backward, takes from a frequency, in dB: each run multiplies the amplitude by 1 / √(1 + (cutoff / freq)⁸)."
  def filter_loss(freq, cutoff) when is_number(freq) and is_number(cutoff) do
    20 * :math.log10(1 + (cutoff / freq) ** 8)
  end

  # Robert Bristow-Johnson's high-pass biquad: the input and output of the two samples before
  # weigh into each output.
  defp biquad(samples, rate, hz, quality) do
    angle = 2 * :math.pi() * hz / rate
    alpha = :math.sin(angle) / (2 * quality)
    cos = :math.cos(angle)
    scale = 1 + alpha

    outer = (1 + cos) / 2 / scale
    middle = -(1 + cos) / scale

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
