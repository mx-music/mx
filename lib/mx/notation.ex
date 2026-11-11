defmodule Mx.Notation do
  @moduledoc """
  Small helpers a song's functions use to choose and tune notes: stepping through a list, drawing seeded random numbers, and intervals in cents or ratios.
  """

  @doc "The item of a list at an index, wrapping round, so `ring(list, pass)` steps one item per pass."
  def ring(list, index) when is_list(list) and is_integer(index) do
    Enum.at(list, rem(index, length(list)))
  end

  @doc "One item of a list or a range, from the seeded random numbers."
  def pick(items) when is_list(items) or is_struct(items, Range), do: Enum.random(items)

  @doc "True about `probability` times in 1, from the seeded random numbers."
  def chance(probability) when is_number(probability), do: :rand.uniform() < probability

  @doc "A number from `low` up to `high`, rounded to two decimals, from the seeded random numbers."
  def between(low, high) when is_number(low) and is_number(high) and low <= high do
    Float.round(low + :rand.uniform() * (high - low), 2)
  end

  @doc "A number kept from `low` up to `high`."
  def clamp(value, low, high)
      when is_number(value) and is_number(low) and is_number(high) and low <= high do
    value |> max(low) |> min(high)
  end

  @doc "An interval in cents as semitones, rounded to two decimals, so `cents(386)` is 3.86."
  def cents(cents) when is_number(cents), do: Float.round(cents / 100, 2)

  @doc "The interval of a frequency ratio in semitones, rounded to two decimals, so `ratio(5 / 4)` is 3.86 and `ratio(2)` is 12."
  def ratio(ratio) when is_number(ratio) and ratio > 0, do: Float.round(12 * :math.log2(ratio), 2)
end
