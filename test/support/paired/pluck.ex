defmodule Mx.Paired.Pluck do
  @moduledoc """
  mxs's pluck written with defsynth, node for node, so the two can be compared and timed.

  Its string's one-pole low-pass is given in Hz where mxs gives its coefficient, so a negative
  coef, which mxs takes, has no twin here.
  """

  use Mx.Instrument

  # The engine's rate, which turns mxs's coefficient into the low-pass's Hz.
  @rate 48_000

  @doc "A Karplus-Strong plucked string: a burst of noise circulating in a delay one period long."
  attr :note, :note, default: 52, doc: "The pitch."

  attr :ring, :seconds,
    default: 3,
    range: 0..1_000_000,
    doc: "How many seconds the string takes to fall 60 dB."

  attr :coef, :float,
    default: 0.3,
    range: -0.99..0.99,
    doc: "How fast the string loses its brightness."

  envelope_attrs sustain: 0, release: 2

  defsynth pluck(o) do
    freq = hz(o.note)
    period = 1 / freq
    burst = lowpass(noise(:white), hz: min(freq * 12, 20_000))
    falling = 0.001 ** (1 / (freq * o.ring))
    # mxs smooths by coef each sample, the one-pole low-pass at this many Hz.
    smoothing = -log2(clamp(o.coef, -0.99, 0.99)) * :math.log(2) * @rate / (2 * :math.pi())

    string =
      fed_back(burst, seconds: period, feedback: falling, lowpass: smoothing, let_in: period)

    note_envelope(dc_block(string, hz: 30) * 0.8, o)
  end
end
