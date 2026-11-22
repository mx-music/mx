defmodule Mx.Paired.Rimshot do
  @moduledoc """
  mxs's rimshot written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [hit: 3, bpf: 3]

  @doc "A rimshot: three short modes of the rim struck at once, and a band of noise from the head."
  attr :note, :note, default: 74, doc: "The rim's pitch."

  defsynth rimshot(o) do
    pitch = hz(o.note)

    modes = Enum.zip([[1, 2.72, 4.3], [1, 0.5, 0.3], [0.06, 0.04, 0.02]])

    rim =
      Enum.reduce(modes, 0, fn {ratio, level, ring}, sound ->
        sound + mode(impulse(), hz: pitch * ratio, level: level, fade: ring)
      end)

    head = bpf(noise(:white), 2400, 1) * hit(0.0005, 0.05, -4) * 0.6

    rings(rim * 0.25 + head, seconds: 0.3)
  end
end
