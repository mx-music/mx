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
    %{level: level, fade: fade} = hits |> Hits.summary() |> Enum.find(&(&1.band == {250, 400}))
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

    %{levels: [start, fifty | _]} = hits |> Hits.moments() |> Enum.find(&(&1.band == {250, 400}))
    assert_in_delta start, 0, 1
    assert_in_delta fifty, -3, 1.5
  end

  test "gives the share of the sound above 1, 2, 4 and 8 kHz over three stretches after the hit starts" do
    [hit] = Hits.hits(swelling(), @rate, nil)
    above = Map.new(hit.brightness, &{&1.above, &1.levels})

    assert Map.keys(above) == [1000, 2000, 4000, 8000]
    [strike, swell, after_it] = above[4000]
    # Over the first 20 ms the high tone rises to 0.4 of its level: a mean power 12.7 dB under
    # its full one.
    assert_in_delta strike, -12.9, 2
    assert_in_delta swell, -3, 2
    assert after_it < swell - 3
    for {low, high} <- Enum.zip(above[1000], above[4000]), do: assert_in_delta(low, high, 0.5)
    # The filter at 8 kHz takes 20 dB from a tone at 6 kHz.
    for {top, high} <- Enum.zip(above[8000], above[4000]), do: assert(top <= high - 15)
  end

  test "gives the milliseconds after the hit starts at which the sound above 4 kHz is loudest" do
    [hit] = Hits.hits(swelling(), @rate, nil)
    assert_in_delta hit.highs_peak, 50, 8
  end

  test "gives the level of the sound above 4 kHz at seven times after the hit starts, under its loudest" do
    [hit] = Hits.hits(swelling(), @rate, nil)
    assert Hits.highs_times() == [5, 10, 20, 40, 80, 160, 320]
    [at_5, at_10, at_20, at_40, at_80, at_160, at_320] = hit.highs
    # The high tone is at 0.1 of its level 5 ms in, 0.2 at 10 ms, 0.4 at 20 ms and 0.8 at 40 ms,
    # then falls 0.2 dB each ms after 50 ms.
    assert_in_delta at_5, -20, 3
    assert_in_delta at_10, -14, 2
    assert_in_delta at_20, -8, 1.5
    assert_in_delta at_40, -2, 1.5
    assert_in_delta at_80, -6, 1.5
    assert_in_delta at_160, -22, 1.5
    assert at_320 <= -50

    [quiet] = Hits.hits(hit(300, [{1, 1}], 0.125), @rate, nil)
    assert quiet.highs == []
    silence = List.duplicate(0.0, @rate)
    hits = Hits.hits(swelling() ++ silence ++ swelling(), @rate, nil)
    highs = Hits.highs(hits)
    assert_in_delta Enum.at(highs, 3), -2, 1.5
  end

  test "a stretch after the hit ends has no share, and a hit with nothing above 4 kHz has no peak there" do
    [hit] = Hits.hits(hit(300, [{1, 1}], 0.125), @rate, nil)
    assert [strike, _swell, nil] = Enum.find(hit.brightness, &(&1.above == 4000)).levels
    assert strike <= -45
    assert hit.highs_peak == nil
  end

  test "brightness gives the medians over the hits, and highs_peak the median peak" do
    silence = List.duplicate(0.0, @rate)
    hits = Hits.hits(swelling() ++ silence ++ swelling(), @rate, nil)
    assert length(hits) == 2

    %{levels: [_strike, swell, _after]} =
      hits |> Hits.brightness() |> Enum.find(&(&1.above == 4000))

    assert_in_delta swell, -3, 2
    assert_in_delta Hits.highs_peak(hits), 50, 8
  end

  # A tone at 150 Hz struck at once and fading 60 dB in a second, under one at 6 kHz as loud as
  # it at its loudest, which swells in over 50 ms and fades 60 dB over the next 300 ms.
  defp swelling do
    for index <- 0..(@rate - 1) do
      time = index / @rate
      low = 10 ** (-3 * time) * :math.sin(2 * :math.pi() * 150 * time)
      rise = if time < 0.05, do: time / 0.05, else: 10 ** (-3 * (time - 0.05) / 0.3)
      0.2 * (low + rise * :math.sin(2 * :math.pi() * 6000 * time))
    end
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
