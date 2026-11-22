defmodule Mx.Paired.Rimshot do
  @moduledoc """
  mxs's rimshot written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @doc "A rimshot: three short modes of the rim struck at once, and a band of noise from the head."
  attr :note, :note, default: 74, doc: "The rim's pitch."

  defsynth rimshot(o) do
    f = hz(o.note)

    rim =
      Enum.zip([[1, 2.72, 4.3], [1, 0.5, 0.3], [0.06, 0.04, 0.02]])
      |> Enum.reduce(0, fn {ratio, level, ring}, sound ->
        sound + (impulse() |> mode(hz: f * ratio, level: level, fade: ring))
      end)

    head = bpf(noise(:white), 2400, 1) * hit(0.0005, 0.05, -4) * 0.6

    (rim * 0.25 + head)
    |> rings(seconds: 0.3)
  end
end
