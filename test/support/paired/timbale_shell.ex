defmodule Mx.Paired.TimbaleShell do
  @moduledoc """
  mxs's timbale shell written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3]

  @doc "The timbale's shell struck by the stick: the stick's crack ringing the shell's short modes, and the crack itself."
  attr :note, :note, default: 93, doc: "The shell's pitch."

  defsynth timbale_shell(o) do
    pitch = hz(o.note)
    stick = highpass(noise(:white), hz: 3000) * hit(0.0002, 0.003, -4)
    freqs = Enum.map([1, 1.38, 1.83, 2.41], &(pitch * &1))
    levels = [1, 0.6, 0.4, 0.25]
    rings = [0.05, 0.04, 0.03, 0.02]

    # The stick rings the shell and sounds itself, so it is shared, its noise drawn once.
    shared =
      share(stick, fn stick ->
        mode(stick, hz: freqs, level: levels, fade: rings) * 0.2 + stick * 0.4
      end)

    rings(shared + mode(impulse(), hz: freqs, level: levels, fade: rings) * 0.2, seconds: 0.25)
  end
end
