defmodule Mx.Test.EffectNodes do
  @moduledoc """
  Effects and a synth that use defeffect's both sides, tail, and the sweep, follower and all-pass
  nodes.
  """

  use Mx.Instrument

  defeffect swap({left, right}, _o), do: {right, left}

  defeffect late(sound, _o), do: delay(sound, seconds: 2.5, max: 3)

  defeffect echo(sound, _o),
    do: sound + fed_back(sound, seconds: 0.25, feedback: 0.5, lowpass: 3000)

  tail(3.0)
  defeffect late_ringing(sound, _o), do: delay(sound, seconds: 2.5, max: 3)

  attr :decay, :beats, default: 4
  tail(:decay)
  defeffect as_long_as_decay(sound, o), do: sound * (o.decay / o.decay)

  defeffect opposite_sweeps({_left, _right}, _o) do
    {sweep(length: 0.5, offset: 0), sweep(length: 0.5, offset: 0.5)}
  end

  attr :rise, :float, default: 0.02
  attr :fall, :float, default: 0.1

  defeffect level_of_tone(_sound, o) do
    follower(sine(hz: 200) * (time() < 0.5), rise: o.rise, fall: o.fall)
  end

  attr :hz, :float, default: 1000
  attr :notch, :float, default: 0

  defeffect all_passed(_sound, o) do
    tone = sine(hz: o.hz)
    tone * o.notch + allpass(tone, hz: 1000)
  end

  attr :note, :note, default: 69
  envelope_attrs sustain: 0.5, release: 0.1

  defsynth swept(o) do
    tone = allpass(sine(hz: hz(o.note)), hz: 1000)
    level = sweep(length: 0.25, wave: 2)
    note_envelope(tone * level * (1 - follower(tone, rise: 0.01, fall: 0.1) * 0.5), o)
  end
end
