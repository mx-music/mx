defmodule Mx.TempoTest do
  use ExUnit.Case, async: true

  alias Mx.Tempo

  test "a rise from 100 to 130 bpm over 16 beats starts at 100, reaches 130 on beat 17, and shortens every beat between" do
    timeline = 100 |> Tempo.new() |> Tempo.put(0, 130, 16)

    lengths =
      for beat <- 0..20, do: Tempo.time_at(timeline, beat + 1) - Tempo.time_at(timeline, beat)

    assert Tempo.tempo_at(timeline, 0) == 100
    assert Tempo.tempo_at(timeline, 16) == 130
    assert_in_delta hd(lengths), 600_000, 10_000
    rising = Enum.take(lengths, 16)
    assert rising == Enum.sort(rising, :desc) and rising == Enum.uniq(rising)

    for length <- Enum.drop(lengths, 16) do
      assert_in_delta length, 60_000_000 / 130, 1
    end
  end

  test "a fall from 120 to 90 bpm over 8 beats ends at 90 and stays there" do
    timeline = 120 |> Tempo.new() |> Tempo.put(4, 90, 8)

    assert Tempo.tempo_at(timeline, 4) == 120
    assert Tempo.tempo_at(timeline, 8) == 105
    assert Tempo.tempo_at(timeline, 12) == 90
    assert Tempo.tempo_at(timeline, 100) == 90
    assert Tempo.time_at(timeline, 13) - Tempo.time_at(timeline, 12) == round(60_000_000 / 90)
  end

  test "a ramp's time comes from the tempo rising evenly over its beats" do
    timeline = 60 |> Tempo.new() |> Tempo.put(0, 120, 4)

    seconds = 4 * :math.log(2) / 60 * 60
    assert_in_delta Tempo.time_at(timeline, 4), seconds * 1_000_000, 1
  end

  test "the beat at a time is the inverse of the time at a beat, through a ramp" do
    timeline = 100 |> Tempo.new(5_000) |> Tempo.put(2, 150, 6) |> Tempo.put(12, 80, 0)

    for beat <- [0, 1.5, 2, 3.25, 7.9, 8, 11, 12, 20] do
      assert_in_delta Tempo.beat_at(timeline, Tempo.time_at(timeline, beat)), beat, 1.0e-5
    end
  end

  test "a change replaces what the timeline held from its beat on, and one inside a ramp starts from the tempo there" do
    timeline = 100 |> Tempo.new() |> Tempo.put(8, 200, 0) |> Tempo.put(4, 140, 0)
    assert Tempo.tempo_at(timeline, 10) == 140

    timeline = 100 |> Tempo.new() |> Tempo.put(0, 200, 10) |> Tempo.put(5, 120, 0)
    assert Tempo.tempo_at(timeline, 4) == 140
    assert Tempo.tempo_at(timeline, 6) == 120
    assert Tempo.tempo_at(timeline, 20) == 120
  end

  test "a song's changes come round again in music that repeats, and only in the first pass of a section that plays until mx stops" do
    repeating = %{sections: {[{0, 140, 0}], []}, lengths: {4, 4}, forever: true}
    assert Tempo.changes(repeating, 0) == [{0, 140, 0}]
    assert Tempo.changes(repeating, 1) == []
    assert Tempo.changes(repeating, 4) == [{0, 140, 0}]

    endless = %{sections: {[], [{0, 90, 2}]}, lengths: {4, :infinity}, forever: false}
    assert Tempo.changes(endless, 1) == [{0, 90, 2}]
    assert Tempo.changes(endless, 2) == []
    assert Tempo.changes(nil, 0) == []
  end

  test "a pass's tempos are described from its start, with the beats of each change in it" do
    tempos = %{
      sections: {[{0, 130, 16}], [], [{0, 90, 8}], [{0, 140, 0}]},
      lengths: {16, 8, 16, 4},
      forever: false
    }

    describe = fn pass ->
      {timeline, start} = Tempo.through(tempos, 100, pass)
      Tempo.describe(timeline, start, start + elem(tempos.lengths, pass))
    end

    assert describe.(0) == "100 bpm, rising to 130 bpm from beat 0 to 16"
    assert describe.(1) == "130 bpm"
    assert describe.(2) == "130 bpm, falling to 90 bpm from beat 0 to 8"
    assert describe.(3) == "140 bpm"

    {timeline, _} = Tempo.through(tempos, 100, 3)

    assert Tempo.describe(timeline, 0, 44) ==
             "100 bpm, rising to 130 bpm from beat 0 to 16, falling to 90 bpm from beat 24 to 32, then 140 bpm from beat 40"

    assert Tempo.describe(timeline, 8, 16) == "115 bpm, rising to 130 bpm until beat 8"
  end
end
