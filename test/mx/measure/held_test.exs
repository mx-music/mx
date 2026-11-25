defmodule Mx.Measure.HeldTest do
  # Measuring keeps every core busy, so it runs after the tests that depend on timing.
  use ExUnit.Case, async: false

  alias Mx.Measure.Held

  @rate 48_000

  test "a tone that rises to its level over 0.1 seconds and holds has an attack of 0.1 seconds" do
    [note] = Held.notes(tone(440, 2.5, attack: 0.1), @rate, 69)
    assert_in_delta note.attack, 0.1, 0.01
  end

  test "finds the vibrato's rate and depth, and none in a steady tone" do
    [swinging] = Held.notes(tone(440, 3, vibrato: {5.5, 20}), @rate, 69)
    assert_in_delta swinging.vibrato.rate, 5.5, 0.3
    assert_in_delta swinging.vibrato.depth, 20, 3

    [steady] = Held.notes(tone(440, 3), @rate, 69)
    assert steady.vibrato == nil
  end

  test "gives the noise between the harmonics as its level in each band, against the fundamental" do
    :rand.seed(:exsss, {1, 2, 3})
    sigma = 0.01
    noisy = Enum.map(tone(440, 3, harmonics: 1), &(&1 + :rand.normal() * sigma))
    [note] = Held.notes(noisy, @rate, 69)
    %{bands: bands} = Held.summary([note])

    # The tone's fundamental has an amplitude of 0.1, so a power of 0.005.
    for %{band: {low, high}, noise: noise} <- bands, low >= 400 do
      expected = 10 * :math.log10(sigma * sigma * (high - low) / (@rate / 2) / 0.005)
      assert_in_delta noise, expected, 3
    end

    assert Enum.any?(bands, &(&1.band == {1000, 1600}))
  end

  test "a note cut off into silence measures the same noise as one that runs to the end" do
    [cut] = Held.notes(tone(440, 3) ++ List.duplicate(0.0, round(@rate * 0.5)), @rate, 69)
    [whole] = Held.notes(tone(440, 3), @rate, 69)

    for {%{level: cut_level}, %{level: whole_level}} <- Enum.zip(cut.noise, whole.noise) do
      assert_in_delta cut_level, whole_level, 3
    end
  end

  test "gives each band's level against the fundamental of the lowest note" do
    [note] = Held.notes(tone(110, 3), @rate, 45)
    summary = Held.summary([note])
    bands = Map.new(summary.bands, &{&1.band, &1})
    assert_in_delta bands[{80, 160}].level, 0, 0.5
    assert_in_delta bands[{160, 250}].level, -6.02, 0.5
  end

  test "splits a file of held notes a semitone apart, each starting from silence" do
    silence = List.duplicate(0.0, round(@rate * 0.5))
    notes = Enum.flat_map(0..2, &(tone(220 * 2 ** (&1 / 12), 2) ++ silence))
    assert notes |> Held.notes(@rate, 57) |> Enum.map(& &1.note) == [57, 58, 59]
  end

  test "leaves out a note that holds nothing within 12 dB of a short burst at its start" do
    silence = List.duplicate(0.0, round(@rate * 0.3))
    quiet = Enum.map(tone(440, 1), &(&1 * 0.02))
    assert Held.notes(silence ++ tone(440, 0.03) ++ quiet, @rate, 69) == []
  end

  # Twelve harmonics at 1/number of the first, or as many as asked, rising linearly over the
  # attack.
  defp tone(f0, seconds, opts \\ []) do
    attack = Keyword.get(opts, :attack, 0.01)
    count = Keyword.get(opts, :harmonics, 12)
    {vibrato_rate, cents} = Keyword.get(opts, :vibrato, {0, 0})

    {samples, _phase} =
      Enum.map_reduce(0..(round(seconds * @rate) - 1), 0.0, fn index, phase ->
        time = index / @rate
        freq = f0 * 2 ** (cents * :math.sin(2 * :math.pi() * vibrato_rate * time) / 1200)
        phase = phase + 2 * :math.pi() * freq / @rate
        level = min(time / attack, 1)
        sum = Enum.sum(for number <- 1..count, do: :math.sin(number * phase) / number)
        {0.1 * level * sum, phase}
      end)

    samples
  end
end
