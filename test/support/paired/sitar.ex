defmodule Mx.Paired.Sitar do
  @moduledoc """
  mxs's sitar written with defsynth, node for node, so the two can be compared and timed.

  mxs also ends the note once its strings fall silent, six seconds after they reach 80 dB below
  full scale; a defsynth has no such end, so its note ends with the envelope alone.
  """

  use Mx.Instrument
  import Mx.Paired.Drums, only: [bpf: 3, hit: 3]
  import Mx.Paired.Sounds, only: [pitch: 1, tilted: 2, along: 3]

  @centres [200, 316, 502, 794, 1265, 2000, 3162, 5019, 7937, 12_649]
  @level_table [10, 19.7, 31.5, 30.3, 22.5, 11.9, 17.9, -0.3, -9, -15]
  @fade_table [12.68, 9.83, 12.68, 9.79, 9.32, 5.55, 3.97, 3.77, 2.4, 2.5]
  @sympathetic [1, 2, 3, 4, 5, 6, 2, 4, 6, 8]
  @sympathetic_levels [1, 0.5, 0.35, 0.25, 0.2, 0.15, 0.7, 0.35, 0.25, 0.15]

  @doc """
  A sitar: a plucked string whose harmonics glide with meend, over sympathetic strings tuned to
  sa.
  """
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  envelope_attrs sustain: 1000, release: 2

  attr :sa, :note,
    default: 49,
    doc: "The note the sympathetic strings are tuned to, and an octave above it."

  attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

  attr :brightness, :float,
    default: 0.5,
    range: 0..1,
    doc: "Tilts the sound 3 dB an octave either way of 0.5."

  defsynth sitar(o) do
    vel = clamp(o.vel, 0, 1)
    freq = hz(o.note)
    harmonics = 1..90

    levels =
      for harmonic <- harmonics do
        level =
          along(@centres, @level_table, freq * harmonic) + (vel - 0.6) * 4 * :math.log2(harmonic)

        select(freq * harmonic < 16_000, db(level), 0)
      end

    fades = for harmonic <- harmonics, do: along(@centres, @fade_table, freq * harmonic)
    # The string glides with its note option, as meend bends it.
    gliding = for harmonic <- harmonics, do: pitch(o) * harmonic
    string = mode(impulse(), hz: gliding, level: levels, fade: fades)
    sa_hz = hz(o.sa)

    # The sympathetic strings ring from the string, which sounds itself too, so it is built once.
    strings =
      share(string, fn plucked ->
        sympathetic =
          mode(lowpass(plucked, hz: 4000) * 0.0001,
            hz: Enum.map(@sympathetic, &(sa_hz * &1)),
            level: @sympathetic_levels,
            fade: List.duplicate(6, 10)
          )

        plucked + sympathetic
      end)

    pick = bpf(noise(:white), freq * 12, 1.2) * hit(0.0005, 0.008, -4) * 0.3
    note_envelope(tilted(o, strings * (0.0007 * (vel / 0.6) ** 1.5) + pick * vel), o)
  end
end
