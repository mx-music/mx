defmodule Mx.FFT do
  @moduledoc """
  The spectrum of a stretch of samples, through a Hann window, as the magnitude of each frequency bin up to half the sample rate.

  The number of samples must be a power of two, unless a power of two to pad them to with silence is given, which draws a short stretch on the bins of a long one.
  """

  @doc "The magnitude of each frequency bin of the samples, from 0 Hz up to half the sample rate."
  def magnitudes(samples, padded \\ nil) when is_list(samples) do
    held = length(samples)
    count = padded || held

    samples
    |> Enum.with_index(fn sample, index ->
      sample * (0.5 - 0.5 * :math.cos(2 * :math.pi() * index / held))
    end)
    |> Enum.concat(List.duplicate(0.0, count - held))
    |> fft()
    |> Enum.take(div(count, 2))
    |> Enum.map(fn {real, imaginary} -> :math.sqrt(real * real + imaginary * imaginary) end)
  end

  defp fft([sample]), do: [{sample, 0.0}]

  defp fft(samples) do
    {evens, odds} = split(samples, [], [])
    step = -2 * :math.pi() / length(samples)
    {low, high} = combine(fft(evens), fft(odds), 0, step, [], [])
    low ++ high
  end

  defp split([even, odd | rest], evens, odds), do: split(rest, [even | evens], [odd | odds])
  defp split([], evens, odds), do: {:lists.reverse(evens), :lists.reverse(odds)}

  defp combine([{even_r, even_i} | evens], [{odd_r, odd_i} | odds], bin, step, low, high) do
    cos = :math.cos(step * bin)
    sin = :math.sin(step * bin)
    turned_r = odd_r * cos - odd_i * sin
    turned_i = odd_r * sin + odd_i * cos
    low = [{even_r + turned_r, even_i + turned_i} | low]
    high = [{even_r - turned_r, even_i - turned_i} | high]
    combine(evens, odds, bin + 1, step, low, high)
  end

  defp combine([], [], _, _, low, high), do: {:lists.reverse(low), :lists.reverse(high)}
end
