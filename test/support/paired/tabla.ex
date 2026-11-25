defmodule Mx.Paired.Tabla do
  @moduledoc """
  mxs's tabla written with defsynth, node for node, so the two can be compared and timed.

  Ghe given a note does not glide with it, as mxs's does, since a defsynth reads its options once, when the note starts.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, nil, 5019, 7937, 12_649]

  @bols %{
    na: %{
      note: 63,
      length: 2,
      ratios: [1.0, 1.789, 2.6931, 3.5927, 3.6525, 4.3152, 4.6887],
      levels: [-20.2, -25.0, 0.0, -25.9, -4.8, -19.3, -3.1],
      rings: [0.166, 1.291, 0.417, 0.312, 0.312, 0.123, 0.123],
      noise: [-90, -90, -90, -90, -90, -90, 8.2, 1.5, -19.9, -26.1, -38.7],
      fades: [0.3, 2.02, 0.166, 1.291, 0.417, 0.315, 0.166, 0.216, 0.407, 0.285, 0.258],
      gain: 0.077,
      high: 2900
    },
    tun: %{
      note: 63,
      length: 3,
      ratios: [1.0108, 1.7922, 2.7313],
      levels: [0.0, -27.7, -22.8],
      rings: [2.332, 2.006, 0.502],
      noise: [-90, -90, -90, -90, -90, -4.0, -8.0, -20.3, -24.2, -26.8, -30.0],
      fades: [13.236, 2.553, 2.332, 2.01, 0.503, 0.479, 0.66, 1.334, 0.777, 1.104, 0.43],
      gain: 0.162,
      high: 2900
    },
    te: %{
      note: 63,
      length: 0.6,
      ratios: [0.3757, 0.6049, 0.7405, 0.9951, 1.1908, 1.7359],
      levels: [-2.4, 0.0, -2.8, -5.3, -2.2, -8.5],
      rings: [0.14, 0.11, 0.14, 0.114, 0.133, 0.128],
      noise: [-90, -90, -90, -90, 17.2, 21.0, 17.2, 13.0, 10.1, 5.7, -8.8],
      fades: [0.451, 0.21, 0.13, 0.128, 0.173, 0.121, 0.136, 0.124, 0.102, 0.106, 0.143],
      gain: 0.043,
      high: 2900
    },
    tas: %{
      note: 63,
      length: 4,
      ratios: [1.0002, 1.2098, 1.7796, 2.696, 3.557, 3.6364],
      levels: [-1.5, 6.7, 12.7, 3.2, 5.2, 14.5],
      rings: [0.34, 0.129, 2.027, 0.375, 0.261, 0.256],
      noise: [-90, -90, 46.5, -90, 48.0, -90, 23.7, 13.9, 8.1, -2.0, -4.0],
      fades: [10.448, 2.321, 0.12, 2.027, 0.1, 0.259, 0.465, 0.546, 0.248, 0.359, 0.299],
      gain: 0.0133,
      high: 2900
    },
    ghe: %{
      note: 42.25,
      length: 5,
      ratios: [1.0, 1.8376, 2.8494, 3.0246, 4.0406, 4.9808],
      levels: [0.0, -28.8, -28.2, -21.0, -36.7, -24.1],
      rings: [3.528, 5.735, 1.599, 1.599, 0.874, 0.553],
      noise: [-90, -90, -90, -90, 3.1, -5.5, -17.9, -25.6, -31.3, -38.9, -40.8],
      fades: [3.528, 5.727, 1.629, 0.553, 0.433, 0.453, 1.63, 10.221, 12.0, 11.327, 12.0],
      gain: 0.14,
      high: 3700
    },
    ke: %{
      note: 44.75,
      length: 0.1,
      ratios: [1.0, 1.8376, 2.8494, 4.0406],
      levels: [0.0, -7.1, -10.0, -6.6],
      rings: [0.06, 0.05, 0.05, 0.04],
      noise: [-90, -90, -90, -90, 18.9, 10.3, 4.1, -2.3, -5.4, -12.6, -23.2],
      fades: List.duplicate(0.05, 11),
      gain: 0.081,
      high: 2900
    }
  }

  @doc "A tabla stroke, by its bol, at the bol's own pitch unless the song gives one."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."

  attr :bol, :atom,
    values: [:na, :tun, :te, :tas, :ghe, :ke],
    default: :na,
    doc: "The stroke: na, tun, te and tas on the dayan, ghe and ke on the bayan."

  attr :note, :note, doc: "The stroke's pitch; each bol has its own when not given."

  defsynth tabla(%{bol: :na} = hit), do: stroke(hit, @bols.na)
  defsynth tabla(%{bol: :tun} = hit), do: stroke(hit, @bols.tun)
  defsynth tabla(%{bol: :te} = hit), do: stroke(hit, @bols.te)
  defsynth tabla(%{bol: :tas} = hit), do: stroke(hit, @bols.tas)
  defsynth tabla(%{bol: :ghe} = hit), do: stroke(hit, @bols.ghe)
  defsynth tabla(%{bol: :ke} = hit), do: stroke(hit, @bols.ke)

  defsoundp stroke(hit, bol) do
    freq = hz(hit.note || bol.note)
    finger = lowpass(impulse(), hz: 3000)

    head =
      mix(
        for {ratio, level, ring} <- Enum.zip([bol.ratios, bol.levels, bol.rings]) do
          mode(finger, hz: ratio * freq, level: db(level), fade: ring)
        end
      )

    centres = List.replace_at(@bands, 7, bol.high)

    hiss =
      mix(
        for {centre, level, fade} <- Enum.zip([centres, bol.noise, bol.fades]), level > -90 do
          noise(:white)
          |> bandpass(hz: freq * (centre / hz(bol.note)), q: 1 / 0.35, poles: 8)
          |> envelope([[0.001, 1], [fade, 0.001, :exp]])
          |> gain(db(level))
        end
      )

    (head + hiss)
    |> highshelf(hz: 1500, db: (hit.vel - 0.6) * 5)
    |> gain(bol.gain * (hit.vel / 0.6) ** 1.5)
    |> rings(seconds: bol.length)
  end
end
