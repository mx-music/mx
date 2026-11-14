defmodule Mx.Measure.HitsTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  alias Mx.Measure.Hits

  @rate 48_000

  test "lists the strongest peaks of a hit as ratios to the lowest" do
    [hit] = Hits.hits(hit(200, [{1, 1}, {3.9, 0.5}, {9.2, 0.3}], 1.5), @rate, nil)
    assert [lowest, second, third] = hit.peaks
    assert lowest == 1.0
    assert_in_delta second, 3.9, 0.039
    assert_in_delta third, 9.2, 0.092
  end

  test "gives each band's level as the hit starts and the seconds it takes to fade 60 dB" do
    [hit] = Hits.hits(hit(300, [{1, 1}, {3.9, 0.5}], 1.0), @rate, nil)
    bands = Map.new(hit.bands, &{&1.band, &1})

    assert_in_delta bands[{250, 400}].level, 0, 0.5
    assert_in_delta bands[{1000, 1600}].level, -6.02, 1
    assert_in_delta bands[{250, 400}].fade, 1.0, 0.1
    assert_in_delta bands[{1000, 1600}].fade, 1.0, 0.1
  end

  test "leaves out the bands below the rumble filter of the note given" do
    [hit] = Hits.hits(hit(1480, [{1, 1}], 0.5), @rate, 90)
    bands = Map.new(hit.bands, &{&1.band, &1})

    refute Map.has_key?(bands, {80, 160})
    refute Map.has_key?(bands, {630, 1000})
    assert_in_delta bands[{1000, 1600}].level, 0, 0.5
  end

  test "finds each hit of a file, one after another from silence, with no note given" do
    silence = List.duplicate(0.0, round(@rate * 0.3))
    one = hit(500, [{1, 1}, {2.7, 0.4}], 0.4)
    assert length(Hits.hits(one ++ silence ++ one ++ silence ++ one, @rate, nil)) == 3
  end

  test "summary gives the median level and fade of each band over the hits" do
    hits = Hits.hits(hit(300, [{1, 1}, {3.9, 0.5}], 1.0), @rate, nil)
    %{level: level, fade: fade} = Enum.find(Hits.summary(hits), &(&1.band == {250, 400}))
    assert_in_delta level, 0, 0.5
    assert_in_delta fade, 1.0, 0.1
  end

  test "with partials:, lists up to that many of the strongest partials, lowest first, with Hz, ratio, level and ring" do
    sound = hit(200, [{1, 1}, {3.9, 0.5}, {9.2, 0.316}], 1.0)
    [hit] = Hits.hits(sound, @rate, nil, partials: 3)
    assert [first, second, third] = hit.partials

    assert_in_delta first.hz, 200, 1
    assert first.ratio == 1.0
    assert first.level == 0.0
    assert_in_delta second.ratio, 3.9, 0.02
    assert_in_delta third.ratio, 9.2, 0.05
    assert_in_delta second.level, -6.0, 1
    assert_in_delta third.level, -10.0, 1

    for partial <- hit.partials, do: assert_in_delta(partial.ring, 1.0, 0.1)

    [hit] = Hits.hits(sound, @rate, nil, partials: 2)
    assert Enum.map(hit.partials, &round(&1.ratio * 10)) == [10, 39]
  end

  test "partials leave out a partial 45 dB below the loudest, and keep two 1 percent apart as one" do
    [hit] = Hits.hits(hit(200, [{1, 1}, {3.9, 0.0056}], 1.0), @rate, nil, partials: 6)
    assert length(hit.partials) == 1

    [hit] = Hits.hits(hit(1000, [{1, 1}, {1.005, 0.5}], 1.0), @rate, nil, partials: 6)
    assert length(hit.partials) == 1
  end

  test "without partials:, a hit lists none" do
    [hit] = Hits.hits(hit(200, [{1, 1}], 1.0), @rate, nil)
    assert hit.partials == []
  end

  test "gives each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment" do
    [hit] = Hits.hits(hit(300, [{1, 1}], 1.0), @rate, nil)
    %{levels: levels} = Enum.find(hit.moments, &(&1.band == {250, 400}))

    for {level, expected} <- Enum.zip(levels, [0, -3, -6, -12]) do
      assert_in_delta level, expected, 1.5
    end
  end

  test "a moment after the hit ends is nil, and one more than 40 dB down is -40" do
    [hit] = Hits.hits(hit(300, [{1, 1}], 0.125), @rate, nil)
    %{levels: [start, _fifty, hundred, nil]} = Enum.find(hit.moments, &(&1.band == {250, 400}))
    assert_in_delta start, 0, 1
    assert hundred == -40
  end

  test "gives where each hit starts, and the medians of the moments over the hits" do
    one = hit(300, [{1, 1}], 1.0)
    silence = List.duplicate(0.0, @rate)
    hits = Hits.hits(one ++ silence ++ one, @rate, nil)
    assert [first, second] = Enum.map(hits, & &1.start)
    assert_in_delta first, 0, 0.01
    assert_in_delta second, 2.2, 0.01

    %{levels: [start, fifty | _]} = Enum.find(Hits.moments(hits), &(&1.band == {250, 400}))
    assert_in_delta start, 0, 1
    assert_in_delta fifty, -3, 1.5
  end

  # Partials at ratios of the lowest, each at its level, all fading 60 dB over `fade` seconds,
  # struck at once.
  defp hit(lowest, partials, fade) do
    seconds = fade * 1.2

    for index <- 0..(round(seconds * @rate) - 1) do
      time = index / @rate
      decay = 10 ** (-3 * time / fade)

      sum =
        Enum.sum(
          for {ratio, level} <- partials,
              do: level * :math.sin(2 * :math.pi() * lowest * ratio * time)
        )

      0.2 * sum * decay
    end
  end
end
