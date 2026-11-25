defmodule Mx.EqTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs.Native

  @moduletag :tmp_dir
  @rate 48_000

  # One second of a synth through eq with the options a song would give it, after half a second to
  # settle, as the left side.
  defp through(bands, synth \\ :noise) do
    {:ok, engine} = Native.start(false, false)
    {:ok, flat} = Mx.Synths.bands(:eq, bands)

    options = for {key, value} <- flat, do: {Atom.to_string(key), value / 1}
    chain = [{"eq", options}]

    {:ok, key} = Native.start_effects(engine, chain)
    event = Mx.Engine.Mxs.event({:note, nil, synth, nil, [note: 57, sustain: 2], %{key: key}})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, _right}} = Native.render(engine, 1.5)
    left = for <<x::float-32-native <- left>>, do: x
    Enum.drop(left, div(@rate, 2))
  end

  # The power of one second of samples at each whole frequency from `low` to `high` Hz, `step`
  # apart, summed.
  defp power(samples, low, high, step \\ 1) do
    Enum.sum(
      for hz <- low..high//step do
        turn = 2 * :math.pi() * hz / @rate

        {re, im, _} =
          Enum.reduce(samples, {0.0, 0.0, 0}, fn x, {re, im, n} ->
            {re + x * :math.cos(turn * n), im + x * :math.sin(turn * n), n + 1}
          end)

        re * re + im * im
      end
    )
  end

  defp db(wet, dry, low, high, step \\ 1) do
    10 * :math.log10(power(wet, low, high, step) / power(dry, low, high, step))
  end

  test "the mid band raises a third of an octave around its note and leaves the far ends" do
    dry = through([])
    wet = through(mid: [at: 69, gain: 6, q: 1])
    assert_in_delta db(wet, dry, 392, 494, 6), 6, 0.5
    assert_in_delta db(wet, dry, 49, 62), 0, 0.5
    assert_in_delta db(wet, dry, 6272, 7902, 90), 0, 0.5
  end

  test "the low band lowers what is below its note and leaves what is far above" do
    dry = through([])
    wet = through(low: [at: 48, gain: -12])
    assert_in_delta db(wet, dry, 36, 45), -12, 1
    assert_in_delta db(wet, dry, 1782, 2245, 30), 0, 0.5
  end

  test "the high band raises what is above its note and leaves what is far below" do
    dry = through([])
    wet = through(high: [at: 96, gain: 6])
    assert_in_delta db(wet, dry, 7127, 8980, 100), 6, 1
    assert_in_delta db(wet, dry, 178, 224, 3), 0, 0.5
  end

  test "eq with no band, or a band with nothing in it, is the dry sound" do
    {:ok, engine} = Native.start(false, false)
    event = Mx.Engine.Mxs.event({:note, nil, :saw, nil, [note: 57, sustain: 2], nil})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, _right}} = Native.render(engine, 1.5)
    samples = for <<sample::float-32-native <- left>>, do: sample
    dry = Enum.drop(samples, div(@rate, 2))
    peak = dry |> Enum.map(&abs/1) |> Enum.max()

    for bands <- [[], [mid: []]] do
      apart = Enum.max(Enum.zip_with(dry, through(bands, :saw), &abs(&1 - &2)))
      assert apart <= peak * 1.0e-5
    end
  end

  defp song(ctx, music) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\nsong(tempo: 120, music: #{music})\n")
    path
  end

  test "a change to a band's gain lowers it over its slide while the note holds", ctx do
    note = "part(:x, note(:a4, 6, release: 0.01), synth: :saw, fx: [eq: [mid: [at: 69, q: 2]]])"
    change = "seq([rest(2), change({:x, :eq}, mid: [gain: -6, gain_slide: 1])])"
    path = song(ctx, "together([#{note}, #{change}])")
    out = Path.join(ctx.tmp_dir, "song.wav")
    capture_io(fn -> refute match?({:error, _}, Mx.Render.render(path, out, [])) end)
    {:ok, %{samples: samples}} = Mx.Audio.read(out)

    left =
      Enum.map(samples, fn sample -> if is_tuple(sample), do: elem(sample, 0), else: sample end)

    at = fn seconds ->
      window = Enum.slice(left, round(seconds * @rate), div(@rate, 10))
      10 * :math.log10(power(window, 440, 440))
    end

    assert_in_delta at.(0.8) - at.(0.5), 0, 0.2
    assert at.(1.2) - at.(0.5) < -1 and at.(1.2) - at.(0.5) > -5
    assert_in_delta at.(1.8) - at.(0.5), -6, 0.3
  end

  test "a band given an option it does not take is refused when the song loads", ctx do
    path = song(ctx, "part(:x, note(:c4, 1), synth: :saw, fx: [eq: [mid: [cutoff: 60]]])")

    assert Mx.Song.load(path) ==
             {:error, "#{path}:2: part x: effect eq's mid has no option cutoff"}

    path = song(ctx, "part(:x, note(:c4, 1), synth: :saw, fx: [eq: [low: [q: 2]]])")
    assert Mx.Song.load(path) == {:error, "#{path}:2: part x: effect eq's low has no option q"}

    path = song(ctx, "part(:x, note(:c4, 1), synth: :saw, fx: [eq: [bass: [gain: 2]]])")
    assert Mx.Song.load(path) == {:error, "#{path}:2: part x: effect eq has no option bass"}

    path = song(ctx, "part(:x, note(:c4, 1), synth: :saw, fx: [eq: [mid: 3]])")

    assert Mx.Song.load(path) ==
             {:error,
              "#{path}:2: part x: effect eq's mid takes a list of its options, such as [gain: 3], not 3"}

    note = "part(:x, note(:c4, 2), synth: :saw, fx: [eq: []])"
    path = song(ctx, "together([#{note}, seq([rest(1), change({:x, :eq}, mid: [cutoff: 60])])])")
    assert Mx.Song.load(path) == {:error, "#{path}:2: effect eq's mid has no option cutoff"}
  end
end
