defmodule Mx.ViolinFitTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs.Native
  alias Mx.Measure.{Held, Strokes}

  @moduletag :engine
  @rate 48_000

  # Medians of the University of Iowa's arco recordings, as mix mx.measure --held gives them: at
  # mf and ff the files sulG.G3B3, sulD.D4A4 (D4B4 at ff), sulA.A4B4, sulA.C5C6 (C5Db6 at ff) and
  # sulE.E5B5, split into the notes listed; at pp the same strings' files cut at their silences
  # into one file a note and each measured with --drone, since mix mx.measure splits a quiet note
  # in two.
  @recordings %{
    0.3 => %{
      notes:
        ~w(a3 as3 g3 gs3 a4 as4 d4 ds4 e4 fs4 g4 gs4 a4 as4 b4 as5 b5 c5 c6 cs5 d5 ds5 e5 f5 fs5 g5 b5 c6 e5 f5 fs5 g5 gs5)a,
      attack: 0.88,
      bands: %{
        {250, 400} => {21.8, -16.7},
        {400, 630} => {23.0, -15.9},
        {630, 1000} => {18.0, -13.5},
        {1000, 1600} => {12.4, -11.4},
        {1600, 2500} => {8.3, -6.8},
        {2500, 4000} => {-0.3, -4.6},
        {4000, 6300} => {-15.8, -7.9},
        {6300, 10_000} => {-29.4, -15.3},
        {10_000, 16_000} => {-29.8, -19.7}
      }
    },
    0.6 => %{
      notes:
        ~w(g3 gs3 a3 as3 as3 b3 d4 ds4 e4 e4 f4 fs4 g4 as4 b4 c5 a4 as4 b4 c5 c5 cs5 d5 ds5 e5 f5 fs5 g5 a5 as5 c6 e5 f5 fs5 g5 gs5 a5 as5 b5)a,
      attack: 0.65,
      bands: %{
        {250, 400} => {20.5, -19.1},
        {400, 630} => {21.4, -16.6},
        {630, 1000} => {14.6, -14.5},
        {1000, 1600} => {11.2, -16.9},
        {1600, 2500} => {12.8, -11.6},
        {2500, 4000} => {5.7, -12.4},
        {4000, 6300} => {-5.8, -14.7},
        {6300, 10_000} => {-18.6, -17.8},
        {10_000, 16_000} => {-24.4, -20.1}
      }
    },
    1 => %{
      notes:
        ~w(g3 gs3 a3 b3 d4 ds4 e4 f4 fs4 g4 gs4 a4 as4 b4 a4 as4 b4 c5 cs5 d5 ds5 e5 fs5 g5 gs5 gs5 a5 b5 c6 e5 f5 fs5 g5 gs5 a5 as5 b5)a,
      attack: 0.33,
      bands: %{
        {250, 400} => {17.3, -14.7},
        {400, 630} => {19.3, -15.1},
        {630, 1000} => {18.4, -11.1},
        {1000, 1600} => {12.9, -10.6},
        {1600, 2500} => {14.5, -7.4},
        {2500, 4000} => {9.2, -8.1},
        {4000, 6300} => {-0.4, -12.7},
        {6300, 10_000} => {-17.6, -15.2},
        {10_000, 16_000} => {-21.1, -17.6}
      }
    }
  }

  defp render(options, seconds) do
    {:ok, engine} = Native.start(false, false)
    :ok = Mx.Instrument.register(engine, Mx.Paired.Violin)
    event = Mx.Engine.Mxs.event({:note, nil, :violin, nil, options, nil})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, _right}} = Native.render(engine, seconds)
    for <<x::float-32-native <- left>>, do: x
  end

  defp midi(name), do: Mx.pitch(name)

  for {vel, %{notes: notes, attack: attack, bands: bands}} <- @recordings do
    test "the violin at vel #{vel} speaks and holds its harmonics and noise as Iowa's arco notes do" do
      notes =
        unquote(notes)
        |> Task.async_stream(
          fn name ->
            note = midi(name)
            sound = render([note: note, vel: unquote(vel), sustain: 4.5, vibrato: 0], 6.5)
            Held.note(sound, @rate, note)
          end,
          timeout: :infinity
        )
        |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)

      summary = Held.summary(notes)
      measured = Map.new(summary.bands, &{&1.band, &1})

      assert_in_delta summary.attack, unquote(attack), 0.1, "attack #{summary.attack} s"

      for {{low, _high} = band, {level, noise}} <- unquote(Macro.escape(bands)) do
        assert_in_delta measured[band].level,
                        level,
                        3,
                        "#{inspect(band)} level #{measured[band].level} dB"

        if low < 4000 do
          assert_in_delta measured[band].noise,
                          noise,
                          6,
                          "#{inspect(band)} noise #{measured[band].noise} dB"
        end
      end
    end
  end

  # Iowa's mf A4 on the A string, held 5.9 seconds, wanders slowly by 1.6 cents in pitch and by
  # 1.8 to 2.9 dB in its 1st, 2nd, 4th and 8th harmonics, as standard deviations of their averages
  # over 0.4 seconds.
  test "the violin's held A4 wanders in pitch and level as slowly and as far as Iowa's mf A4" do
    sound = render([note: 69, vel: 0.6, sustain: 5.5, vibrato: 0], 6)
    %{strokes: [_ | _]} = recording = Strokes.strokes(sound, @rate)
    %{cents: cents, levels: levels} = Strokes.tracks(recording, 0)
    steady = 60..599

    slow = fn values ->
      values = Enum.slice(values, steady)

      values
      |> Enum.with_index()
      |> Enum.map(fn {_, i} -> values |> Enum.slice(max(i - 25, 0)..(i + 24)) |> mean() end)
      |> deviation()
    end

    assert_in_delta slow.(cents), 1.6, 0.8

    for harmonic <- [0, 1, 3, 7] do
      wander = levels |> Enum.map(&Enum.at(&1, harmonic)) |> slow.()
      assert wander > 1.2 and wander < 4, "harmonic #{harmonic + 1} wanders #{wander} dB"
    end
  end

  defp mean(values), do: Enum.sum(values) / length(values)

  defp deviation(values) do
    average = mean(values)
    values |> Enum.map(&((&1 - average) ** 2)) |> mean() |> :math.sqrt()
  end
end
