defmodule Mx.Measure.StrokesTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  alias Mx.Measure.Strokes

  @rate 48_000
  @silence List.duplicate(0.0, 2400)

  test "finds each stroke between two dips of the level, with its note and where its pitch starts" do
    run = @silence ++ stroke(330) ++ stroke(330) ++ stroke(660) ++ @silence
    assert %{strokes: [first, second, third]} = Strokes.strokes(run, @rate)

    assert_in_delta first.from, 0.07, 0.02
    assert_in_delta first.to, 0.18, 0.02
    assert_in_delta second.from - first.from, 0.15, 0.01
    assert_in_delta first.note, 64.02, 0.05
    assert_in_delta third.note, 76.02, 0.05
    assert first.start < -40
    assert_in_delta first.level, 0, 1
  end

  test "finds no strokes in silence" do
    assert %{strokes: []} = Strokes.strokes(List.duplicate(0.0, @rate), @rate)
  end

  test "tracks give a stroke's pitch in cents against its note and the level of each harmonic at every step" do
    recording = Strokes.strokes(@silence ++ stroke(330) ++ stroke(330) ++ @silence, @rate)

    assert %{note: note, scoop: scoop, body: body, cents: cents, levels: levels} =
             Strokes.tracks(recording, 0)

    assert_in_delta note, 64.02, 0.05
    assert scoop > 0.4
    assert body == length(cents)
    assert length(levels) == body
    assert hd(cents) < -40
    for late <- Enum.slice(cents, 7, 5), do: assert_in_delta(late, 0, 5)

    assert [first, second, third | rest] = Enum.at(levels, div(body, 2))
    assert first in -1..0
    assert second in -1..0
    assert_in_delta third, -6.5, 1
    assert Enum.all?(rest, &(&1 < -40))
  end

  test "with alone:, the tracks carry on into the ring after the stroke, with no noise" do
    ring = for sample <- tone(330, 0.1), do: sample * 0.004
    recording = Strokes.strokes(@silence ++ stroke(330) ++ ring ++ @silence, @rate)

    within = Strokes.tracks(recording, 0)
    alone = Strokes.tracks(recording, 0, alone: true)

    assert alone.body == within.body
    assert length(alone.cents) > alone.body + 5
    assert length(alone.levels) == length(alone.cents)
    for step <- Enum.drop(alone.levels, alone.body), do: assert(List.last(step) == -127)
  end

  test "with ignore:, the tracks leave out the harmonics between two frequencies" do
    recording = Strokes.strokes(@silence ++ stroke(330) ++ @silence, @rate)
    %{levels: levels} = Strokes.tracks(recording, 0, ignore: {600, 700})

    for [first, second | _] <- levels do
      assert second == -127
      assert first > -40
    end
  end

  test "file names a recording it cannot read" do
    assert Strokes.file("missing.wav") == {:error, "cannot read missing.wav"}
  end

  # A stroke of 150 ms whose level rises from 34 dB down and falls back, with harmonics at 1, 1
  # and 0.5, starting 100 cents flat for 40 ms.
  defp stroke(hz) do
    count = round(0.15 * @rate)

    {samples, _} =
      Enum.map_reduce(0..(count - 1), 0.0, fn index, phase ->
        seconds = index / @rate
        bent = hz * 2 ** (-100 / 1200 * max(0.0, 1 - seconds / 0.04))
        level = 0.02 + 0.48 * :math.sin(:math.pi() * index / count) ** 2
        sample = :math.sin(phase) + :math.sin(2 * phase) + 0.5 * :math.sin(3 * phase)
        {level * sample / 2.5, phase + 2 * :math.pi() * bent / @rate}
      end)

    samples
  end

  defp tone(hz, seconds) do
    for index <- 0..(round(seconds * @rate) - 1),
        do: :math.sin(2 * :math.pi() * hz * index / @rate)
  end
end
