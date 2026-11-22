defmodule Mx.Paired.Berimbau do
  @moduledoc """
  mxs's berimbau written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Instrument
  import Mx.Paired.Draws, only: [rnd1: 1]
  alias Mx.Instrument.Vocabulary, as: V

  @ratios [2, 3, 4, 5, 6, 7, 9, 10, 12, 14, 16, 19.35, 20.38, 21, 21.47, 35, 37, 39, 44]
  @open [
    -10,
    0,
    -15.5,
    0,
    -8,
    -10,
    -10,
    -8,
    -14.6,
    -13.5,
    -11.6,
    -12,
    -12,
    -9.9,
    -12,
    -15.4,
    -10.8,
    -12.7,
    -11.6
  ]
  @pressed [
    -30,
    0,
    -5.4,
    -7.6,
    -7.9,
    -30,
    -30,
    -30,
    -30,
    -30,
    -30,
    -30,
    -30,
    -30,
    -30,
    -5,
    -3.1,
    -7.1,
    -6
  ]
  @rings [2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2, 2, 2, 2, 1, 1, 1, 0.8]
  @swings %{2 => -4.5, 3 => -7, 5 => 12, 6 => 13}
  @bands [794, 1265, 2000, 3162, 5019, 7937, 12_649]
  @wire_open [-14, -8, -6, 17, 8, 6, 3]
  @wire_pressed [-14, -8, -3, 15, 10, 6, 5]
  @wire_rings [0.6, 0.6, 0.5, 0.25, 0.08, 0.07, 0.06]
  @tails [-60, -60, -60, -40, -22, -28, -24]
  @wire_fit [-10, -15.8, -12.9, -14.3, -7, -6.6, -12.8]
  @seed 7000
  @wire (for index <- 0..95 do
           band = 700 * :math.pow(16_000 / 700, (index + rnd1(2 * index + @seed)) / 96)
           {band, 0.2 * :math.pow(30, rnd1(2 * index + @seed + 1)), rem(index, 4) == 0}
         end)

  @doc "The berimbau: the string's partials struck by the stick, swung by the gourd, over the wire's close modes and the stick's thud."
  attr :note, :note, default: 39.11, doc: "The open string's pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the stick strikes."

  attr :coin, :float,
    default: 0,
    range: 0..1,
    doc: "How hard the coin presses the wire, raising it a whole tone."

  attr :buzz, :float,
    default: 0,
    range: 0..1,
    doc: "How loosely the coin rests on the wire, rattling against it."

  attr :gourd, :float,
    default: 2.3,
    range: 0..20,
    doc: "How many times a second the gourd swings against the belly."

  defsynth berimbau(o) do
    vel = o.vel
    buzz = o.buzz
    coin = max(o.coin, buzz)
    mix = fn a, b -> a + (b - a) * coin end
    pitch = hz(o.note) * 1.0621 ** coin
    damp = 1 - buzz * 0.96
    gourd = o.gourd
    stick = lowpass(impulse(), hz: 5000)

    # The gourd starts open and swings some harmonics up and others down as it closes against the
    # belly.
    partials = Enum.zip([@ratios, @open, @pressed, @rings])

    string =
      Enum.reduce(partials, 0, fn {ratio, open, pressed, ring}, string ->
        partial =
          mode(stick, hz: pitch * ratio, level: db(mix.(open, pressed)), fade: ring * damp)

        case @swings[ratio] do
          nil ->
            string + partial

          swing ->
            string +
              partial * select(gourd > 0, db(cos(2 * :math.pi() * gourd * time()) * swing), 1)
        end
      end)

    # The wire's levels, rings and tails read at a frequency along its bands; the levels move with
    # the coin.
    wire_levels =
      Enum.zip_with([@wire_open, @wire_pressed, @wire_fit], fn [a, b, fit] -> mix.(a, b) + fit end)

    wire =
      mode(V.noise(:white, seed: 1) * perc(attack: 0.0002, release: 0.002) * 0.6,
        hz: Enum.map(@wire, &elem(&1, 0)),
        level:
          Enum.map(@wire, fn {wf, _, long} ->
            db(at(wf, wire_levels)) * if(long, do: db(at(wf, @tails) + 10), else: 1)
          end),
        fade:
          Enum.map(@wire, fn {wf, spread, long} ->
            if(long, do: 1.5, else: min(at(wf, @wire_rings) * spread, 2.5)) * damp ** 0.5
          end)
      )

    # The stick's dull thud, in three bands of noise that rise at once and fall away
    # exponentially.
    thud =
      [{200, -20, 0.3}, {316, -20, 0.3}, {502, -10, 0.5}]
      |> Enum.with_index()
      |> Enum.reduce(0, fn {{centre, level, fade}, i}, thud ->
        fall = envelope([{0.001, 1}, {fade * damp ** 0.5, 0.001, :exp}, {0.01, 0}])

        band =
          V.noise(:white, seed: 2 + i)
          |> bandpass(hz: centre, q: 1 / 0.35)
          |> bandpass(hz: centre, q: 1 / 0.35)
          |> bandpass(hz: centre, q: 1 / 0.35)

        thud + band * fall * db(level)
      end)

    tick = highpass(impulse(), hz: 200) * 0.1

    # With buzz, the coin rests on the wire and rattles against it; at 0 the rattle is silent,
    # where mxs leaves it out.
    rattle =
      highpass(V.pulse(hz: pitch, width: 0.08) * 0.5 + 0.42, hz: 1200) *
        perc(attack: 0.002, release: 0.12) *
        (buzz * 0.3)

    sound = string * 0.05 + thud + wire * 0.05 + tick + rattle

    rings(
      highshelf(sound, hz: 1500, q: 0.707, db: (vel - 0.6) * 5) * (0.2 * (vel / 0.6) ** 1.5),
      seconds: 2.9
    )
  end

  # A value read at `freq` from `table` along the wire's bands, held beyond them.
  defsoundp at(freq, table) do
    freq = freq |> Kernel.max(hd(@bands)) |> Kernel.min(List.last(@bands))
    index = Kernel.min(Enum.count(@bands, &(&1 <= freq)) - 1, 5)
    low = Enum.at(@bands, index)
    high = Enum.at(@bands, index + 1)

    Enum.at(table, index) +
      (Enum.at(table, index + 1) - Enum.at(table, index)) * ((freq - low) / (high - low))
  end
end
