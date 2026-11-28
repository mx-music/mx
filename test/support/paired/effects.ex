defmodule Mx.Paired.Effects do
  @moduledoc """
  mxs's pan, tremolo and slicer written with defeffect, node for node, so the two forms can be
  compared.
  """

  use Mx.Instrument

  @doc "Turns the sound towards one side."
  attr :pan, :float, default: 0, range: -1..1, doc: "From -1, left, to 1, right."

  defeffect pan_twin({left, right}, o) do
    pan = clamp(follow(o.pan), -1, 1)
    {left * min(1 - pan, 1), right * min(1 + pan, 1)}
  end

  @doc "Turns the sound down and back up in a sweep."
  attr :phase, :beats, default: 4, doc: "How long one sweep takes."
  attr :wave, :float, default: 2, range: 0..4, doc: "The sweep's shape."
  attr :invert_wave, :float, default: 0, range: 0..1, doc: "1 flips the sweep."
  attr :phase_offset, :float, default: 0, range: 0..1, doc: "Where in the sweep it starts."
  attr :depth, :float, default: 0.5, range: 0..1, doc: "How far it turns the sound down."

  defeffect tremolo_twin(sound, o) do
    level =
      sweep(
        length: follow(o.phase),
        wave: follow(o.wave),
        invert: follow(o.invert_wave),
        offset: o.phase_offset
      )

    sound * (1 - follow(o.depth) * level)
  end

  @doc "Turns the sound on and off in time."
  attr :phase, :beats, default: 0.25, doc: "The length of a cycle."
  attr :phase_offset, :float, default: 0, range: 0..1, doc: "Where in the cycle it starts."
  attr :pulse_width, :float, default: 0.5, range: 0..1, doc: "The part of the cycle that is on."
  attr :amp_min, :float, default: 0, doc: "The level while off."
  attr :amp_max, :float, default: 1, doc: "The level while on."
  attr :smooth_ms, :ms, default: 0, doc: "How long each change takes."

  defeffect slicer_twin(sound, o) do
    open =
      sweep(
        length: follow(o.phase),
        wave: 1,
        width: follow(o.pulse_width),
        offset: o.phase_offset
      )

    low = follow(o.amp_min)
    level = lag(low + open * (follow(o.amp_max) - low), seconds: o.smooth_ms / 1000)
    sound * level
  end
end
