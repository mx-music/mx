defmodule Mx.Paired.Kick do
  @moduledoc """
  mxs's kick written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument

  @doc "A kick drum: a sine swept down from 26 semitones above the note, a beater's click and a shell mode, driven."
  attr :note, :note, default: 34, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :beater, :float,
    default: 1,
    range: 0..1,
    doc: "How hard the beater is; 0 is a felt beater."

  defsynth kick(o) do
    note = o.note
    vel = clamp(o.vel, 0, 1)
    hard = o.beater

    # The graph's envelopes start at 0, so the sweep from 26 semitones down is 26 less one rising
    # to 26.
    sweep = hz(note + (26 - envelope([{0.07, 26, -6}])))
    body = sine(hz: sweep, phase: :math.pi() / 2) * hit(0.001 + 0.004 * (1 - hard), 0.55, -5)

    beater =
      highpass(noise(:white), hz: 1800, q: :math.sqrt(0.5)) * hit(0.0005, 0.012, -4) *
        (0.3 * hard * db((vel - 0.6) * 20))

    shell = mode(impulse(), hz: hz(note) * 1.75, level: 0.1, fade: 1.5)

    # tanh, written with the sound once, since an expression used twice is built twice and its
    # noise drawn twice.
    struck = 1 - 2 / (exp(2 * (body + beater)) + 1)

    rings((struck + shell) * (vel / 0.6) ** 2.5, seconds: 1.5)
  end

  defsoundp hit(attack, decay, curve) do
    envelope([{attack, 1, curve}, {decay, 0, curve}])
  end
end
