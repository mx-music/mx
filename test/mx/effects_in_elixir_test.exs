defmodule Mx.EffectsInElixirTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs.Native

  @rate 48_000

  # A saw note through a chain of effects, each `{effect, options}` with its times in seconds, as both sides.
  defp through(effects, seconds \\ 1.5, note \\ [note: 57, sustain: 1]) do
    {:ok, engine} = Native.start(false, false)
    :ok = Mx.Instrument.register(engine, Mx.Paired.Effects)
    :ok = Mx.Instrument.register(engine, Mx.Test.EffectNodes)

    chain =
      for {effect, options} <- effects do
        {Atom.to_string(effect),
         for({key, value} <- options, do: {Atom.to_string(key), value / 1})}
      end

    {:ok, key} = Native.start_effects(engine, chain)
    event = Mx.Engine.Mxs.event({:note, nil, :saw, nil, note, %{key: key}})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, right}} = Native.render(engine, seconds)
    {floats(left), floats(right)}
  end

  defp floats(binary), do: for(<<x::float-32-native <- binary>>, do: x)

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()

  defp rms(samples), do: :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / length(samples))

  # How far below the first render's peak the two renders differ at most, on either side, in decibels.
  defp apart({left, right}, {other_left, other_right}) do
    difference =
      max(
        peak(Enum.zip_with(left, other_left, &(&1 - &2))),
        peak(Enum.zip_with(right, other_right, &(&1 - &2)))
      )

    20 * :math.log10(max(difference, 1.0e-12) / max(peak(left), peak(right)))
  end

  defp at(samples, seconds), do: Enum.at(samples, round(seconds * @rate))

  test "an echo of the fed-back delay with a low-pass in its loop sounds each repeat duller than the one before" do
    {left, _right} = through([echo: []], 1, note: 57, sustain: 0.02, release: 0.02)

    brightness =
      for repeat <- 1..3 do
        heard = Enum.slice(left, round(repeat * 0.25 * @rate), round(0.2 * @rate))
        rms(Enum.zip_with(tl(heard), heard, &(&1 - &2))) / rms(heard)
      end

    assert brightness == Enum.sort(brightness, :desc) and length(Enum.uniq(brightness)) == 3
  end

  test "an effect over both sides that swaps them moves a note on the left to the right" do
    {left, right} = through(pan: [pan: -1])
    assert peak(left) > 0.01 and peak(right) == 0.0

    {left, right} = through(pan: [pan: -1], swap: [])
    assert peak(right) > 0.01 and peak(left) == 0.0
  end

  test "an effect that takes both sides and returns one sound fails when its module compiles" do
    source = """
    defmodule Mx.EffectsInElixirTest.OneSided do
      use Mx.Instrument
      defeffect one_sided({left, right}, _o), do: left + right
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "one_sided.exs") end
    assert error.line == 3

    assert Exception.message(error) =~
             "one_sided takes both sides, {left, right}, so it returns both"

    source = """
    defmodule Mx.EffectsInElixirTest.TwoFromOne do
      use Mx.Instrument
      defeffect two_from_one(sound, _o), do: {sound, sound}
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "two_from_one.exs") end
    assert Exception.message(error) =~ "two_from_one takes one sound, so it returns one"
  end

  test "a tail that is neither seconds nor one of the effect's options fails when its module compiles" do
    source = """
    defmodule Mx.EffectsInElixirTest.BadTail do
      use Mx.Instrument
      tail :decay
      defeffect bad_tail(sound, _o), do: sound
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "bad_tail.exs") end

    assert Exception.message(error) =~
             "bad_tail's tail takes seconds, a number from 0 up, or the name of one of its options, not :decay"
  end

  test "the twin of pan written with defeffect matches pan" do
    for pan <- [-1, 0, 0.5] do
      assert apart(through(pan: [pan: pan]), through(pan_twin: [pan: pan])) < -60
    end
  end

  test "the twin of tremolo written with the sweep node matches tremolo at each wave" do
    for wave <- 0..4 do
      options = [phase: 0.3, wave: wave, depth: 0.8, phase_offset: 0.2]
      assert apart(through(tremolo: options), through(tremolo_twin: options)) < -60
    end

    options = [phase: 0.3, invert_wave: 1]
    assert apart(through(tremolo: options), through(tremolo_twin: options)) < -60
    assert apart(through(tremolo: options), through(tremolo_twin: [phase: 0.3])) > -20
  end

  test "the twin of slicer written with the sweep node matches slicer" do
    for options <- [
          [],
          [phase: 0.2, pulse_width: 0.3, amp_min: 0.2, phase_offset: 0.4],
          [phase: 0.2, smooth_ms: 20]
        ] do
      assert apart(through(slicer: options), through(slicer_twin: options)) < -60
    end
  end

  test "a sweep that starts half a cycle later on the right is lowest there when highest on the left" do
    {left, right} = through(opposite_sweeps: [])
    assert at(left, 0.125) > 0.999 and at(right, 0.125) < 0.001
    assert at(left, 0.375) < 0.001 and at(right, 0.375) > 0.999
  end

  test "the follower reaches nine tenths of a tone's level within its rise and falls below a tenth within its fall" do
    {level, _right} = through(level_of_tone: [])
    assert at(level, 0.02) >= 0.9
    assert at(level, 0.4) > 0.9 and at(level, 0.4) <= 1.0
    assert at(level, 0.55) > 0.2
    assert at(level, 0.6) < 0.1
  end

  test "the all-pass keeps every frequency's level, and added to the dry sound it cuts a notch at its frequency" do
    steady = fn options ->
      {left, _right} = through(all_passed: options)
      rms(Enum.drop(left, div(@rate, 2)))
    end

    for hz <- [250, 500, 1000, 2000, 4000] do
      assert_in_delta 20 * :math.log10(steady.(hz: hz) / :math.sqrt(0.5)), 0, 0.1
    end

    assert 20 * :math.log10(steady.(hz: 1000, notch: 1) / steady.(hz: 250, notch: 1)) < -30
  end

  test "a node given an argument it does not take is refused when the effect registers" do
    # The graph is handed over as defeffect would, without a module that every engine would then load.
    input = %Mx.Instrument.Expr{op: :input, args: []}
    graph = Mx.Instrument.encode(Mx.Instrument.Vocabulary.allpass(input, hz: 1000, seconds: 1))
    {:ok, engine} = Native.start(false, false)

    assert Native.register_effect_graph(engine, "bad_allpass", [], graph) ==
             {:error, "bad_allpass: allpass does not take seconds:"}
  end

  test "a defsynth calls the sweep, the follower and the all-pass" do
    {:ok, engine} = Native.start(false, false)
    :ok = Mx.Instrument.register(engine, Mx.Test.EffectNodes)
    event = Mx.Engine.Mxs.event({:note, nil, :swept, nil, [note: 69], nil})
    :ok = Native.play(engine, [{0.0, event}])
    {:ok, {left, _right}} = Native.render(engine, 0.5)
    left = floats(left)

    # The triangle sweep is at its top a quarter of its 0.25 seconds in, and at 0 at three quarters.
    assert peak(Enum.slice(left, 2400, 1200)) > 3 * peak(Enum.slice(left, 8400, 1200))
  end
end
