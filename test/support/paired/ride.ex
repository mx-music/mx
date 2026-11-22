defmodule Mx.Paired.Ride do
  @moduledoc """
  mxs's ride written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Drums

  @bands [200, 300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]
  @levels [0, -7.4, -5.6, -20.4, 2.4, -13.5, 6.5, 8, 2.1, 11.3]
  @rings [20, 12.2, 8.7, 7.65, 6.37, 5.78, 4.47, 3.67, 2.76, 2.79]
  @bell_hz [
    271.2,
    284.9,
    1193.8,
    2340.4,
    3435.8,
    4295.8,
    4834.8,
    4900.5,
    4974,
    5941,
    6084.5,
    7322.7,
    8958.5
  ]
  @bell_levels [-3, -4.5, -6.1, -4.5, -7.7, -5.2, 0, -0.2, -1.1, -5.2, -3.9, -5.1, -4.5]
  @bell_rings [6.38, 6.38, 3.26, 2.98, 2.83, 2.2, 1.44, 1.4, 1.94, 1.44, 1.12, 1.26, 0.97]
  # The fitted dBs after the bands' levels: the high bands' noise, how much quieter the plate is above 1 kHz, the tick, and the ping.
  @high_db 30
  @quieter_db 22
  @tick_db 26
  @ping_db -14
  # The bell's own: the cup, the wash, the ping, the cup's two lowest modes, and the tick.
  @cup_db -14
  @bell_wash -8
  @bell_ping 0
  @cup_low 22
  @bell_tick 0
  @plate Mx.Paired.Draws.plate(160, 150, 16_000)

  @doc "A ride cymbal: a stick ringing the plate's modes as a long wash and a short ping, noise in the high bands, a tick, and the bell's cup."
  attr :note, :note, default: 60, doc: "The drum's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
  attr :sustain, :beats, default: 8, doc: "How long it rings before it is damped."
  attr :release, :beats, default: 3, doc: "How long the damping takes."
  attr :bell, :float, default: 0, range: 0..1, doc: "1 strikes the bell instead of the bow."

  defsynth ride(o) do
    bell = o.bell
    vel = clamp(o.vel, 0, 1)
    scale = 2 ** ((o.note - 60) / 12)
    tilt = (vel - 0.6) * 4
    wash_db = -13 + bell * @bell_wash
    ping_db = @ping_db + bell * (@bell_ping - @ping_db)

    stick =
      (noise(:white) |> highpass(hz: 1000) |> highshelf(hz: 3000, q: 0.707, db: tilt)) *
        hit(0.0005, 0.01, -4)

    groups =
      for some <- @plate do
        levels =
          Enum.map(some, fn f ->
            quieter =
              cond do
                f < 1000 -> 0
                f < 3000 -> @quieter_db
                f < 6000 -> @quieter_db + 6
                true -> @quieter_db + 14
              end

            db(between(f, @bands, @levels) - quieter)
          end)

        freqs = Enum.map(some, &(&1 * scale))
        rings = Enum.map(some, &between(&1, @bands, @rings))
        pinged = &Enum.take_every(&1, 3)
        {freqs, levels, rings, pinged.(freqs), pinged.(levels)}
      end

    wash_hz = Enum.flat_map(groups, &elem(&1, 0))
    wash_levels = Enum.flat_map(groups, &elem(&1, 1))
    wash_rings = Enum.flat_map(groups, &elem(&1, 2))
    ping_hz = Enum.flat_map(groups, &elem(&1, 3))
    ping_levels = Enum.flat_map(groups, &elem(&1, 4))

    cup_levels =
      Enum.map(Enum.take(@bell_levels, 2), &db(&1 + @cup_low)) ++
        Enum.map(Enum.drop(@bell_levels, 2), &db(&1))

    cup_level = bell * db(@cup_db)

    # The wash, the ping and the cup are each a bank struck by the stick and scaled by a number fixed as the note starts, so one bank holds all three and the stick's noise is drawn once.
    struck =
      mode(stick,
        hz: wash_hz ++ ping_hz ++ Enum.map(@bell_hz, &(&1 * scale)),
        level:
          Enum.map(wash_levels, &(&1 * db(wash_db))) ++
            Enum.map(ping_levels, &(&1 * db(ping_db))) ++ Enum.map(cup_levels, &(&1 * cup_level)),
        fade: wash_rings ++ List.duplicate(0.35, length(ping_hz)) ++ @bell_rings
      )

    tilted = &highshelf(&1, hz: 3000, q: 0.707, db: tilt)
    high = Enum.drop(@levels, 3)
    wash_noise = tilted.(band_noise(high, Enum.drop(@rings, 3), 3, scale)) * db(@high_db)
    ping_noise = tilted.(band_noise(high, List.duplicate(0.35, 7), 3, scale)) * db(@high_db)

    tick =
      highpass(noise(:white), hz: 4000 * scale) * hit(0.0005, 0.015, -4) * db(@tick_db) *
        db(bell * @bell_tick)

    held = o.sustain
    release = o.release
    # The damping falls from 1, so it is 1 less an envelope rising from the graph's 0.
    choke = 1 - envelope([{held, 0}, {release, 1, -4}])

    ((struck + wash_noise * db(wash_db) + ping_noise * db(ping_db) + tick) * 0.007 * db(bell * -4) *
       choke * (vel / 0.6) ** 1.7)
    |> rings(seconds: held + release)
  end
end
