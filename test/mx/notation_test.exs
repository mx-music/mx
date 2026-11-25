defmodule Mx.NotationTest do
  use ExUnit.Case, async: true

  test "the notation guide describes every word a song can use" do
    notation = File.read!("documentation/notation.md")

    functions = Mx.__info__(:functions)
    words = functions |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

    missing =
      Enum.reject(words, fn word ->
        quoted = Regex.escape("`#{word}")
        notation =~ ~r/#{quoted}[`( ]/
      end)

    assert missing == []
  end

  test "pick is an item of the list, the same each time the random numbers are seeded the same" do
    picks = fn ->
      :rand.seed(:exsss, {1, 2, 3}) && Enum.map(1..50, fn _ -> Mx.pick([61, 62, 63]) end)
    end

    picked = picks.()

    assert Enum.all?(picked, &(&1 in [61, 62, 63]))
    assert picked |> Enum.uniq() |> length() == 3
    assert picks.() == picked
  end

  test "chance(0.45) is true about 45 times in 100" do
    hits = Enum.count(1..1000, fn _ -> Mx.chance(0.45) end)
    assert hits >= 400 and hits <= 500
  end

  test "between is a number in the range, rounded to two decimals" do
    for _ <- 1..200 do
      amp = Mx.between(0.6, 0.95)
      assert amp >= 0.6 and amp <= 0.95
      assert Float.round(amp, 2) == amp
    end
  end

  test "clamp keeps a number within a range" do
    assert Enum.map([12, 1, 5], &Mx.clamp(&1, 2, 11)) == [11, 2, 5]
  end

  test "cents and ratio are intervals in semitones" do
    assert 60 + Mx.cents(386) == 63.86
    assert 60 + Mx.ratio(5 / 4) == 63.86
    assert Mx.ratio(2) == 12.0
  end
end
