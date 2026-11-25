defmodule Mx.Instruments.Tabla do
  @moduledoc """
  The tabla, measured from the CC0 "tabla bols" pack by mmiron on Freesound.

  Each bol is a stroke: the head's modes as ratios of the note's frequency, each with a level in dB and the seconds it rings, and noise in bands from 113 Hz up, each with a level in dB and the seconds it fades.
  The bands move with the note, so a note retunes the whole stroke, and a harder stroke is louder and brighter.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, 2900, 5019, 7937, 12_649]

  @doc "A tabla stroke, by its bol, at the bol's own pitch unless the song gives one."
  attr :note, :note, doc: "The pitch; the bol's own pitch when not given."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the stroke is."
  attr :bol, :atom, values: [:na, :tun, :te, :tas, :ghe, :ke], default: :na, doc: "The stroke."

  defsynth tabla(%{bol: :na} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.077,
      modes: [
        {1.0, -20.2, 0.166},
        {1.789, -25.0, 1.291},
        {2.6931, 0.0, 0.417},
        {3.5927, -25.9, 0.312},
        {3.6525, -4.8, 0.312},
        {4.3152, -19.3, 0.123},
        {4.6887, -4.1, 0.123}
      ],
      noise: [
        {-90, 0.3},
        {-90, 2.02},
        {-90, 0.166},
        {-90, 1.291},
        {-90, 0.417},
        {-90, 0.315},
        {8.2, 0.166},
        {1.5, 0.216},
        {-19.9, 0.407},
        {-26.1, 0.285},
        {-38.7, 0.258}
      ]
    )
    |> rings(seconds: 2)
  end

  defsynth tabla(%{bol: :tun} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.162,
      modes: [{1.0108, 0.0, 2.332}, {1.7922, -27.7, 2.006}, {2.7313, -22.8, 0.502}],
      noise: [
        {-90, 13.236},
        {-90, 2.553},
        {-90, 2.332},
        {-90, 2.01},
        {-90, 0.503},
        {-4.0, 0.479},
        {-8.0, 0.66},
        {-20.3, 1.334},
        {-24.2, 0.777},
        {-26.8, 1.104},
        {-30, 0.43}
      ]
    )
    |> rings(seconds: 3)
  end

  defsynth tabla(%{bol: :te} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.043,
      modes: [
        {0.3757, -2.4, 0.14},
        {0.6049, 0.0, 0.11},
        {0.7405, -2.8, 0.14},
        {0.9951, -5.3, 0.114},
        {1.1908, -2.2, 0.133},
        {1.7359, -8.5, 0.128}
      ],
      noise: [
        {-90, 0.451},
        {-90, 0.21},
        {-90, 0.13},
        {-90, 0.128},
        {17.2, 0.173},
        {21.0, 0.121},
        {17.2, 0.136},
        {13.0, 0.124},
        {10.1, 0.102},
        {5.7, 0.106},
        {-8.8, 0.143}
      ]
    )
    |> rings(seconds: 0.6)
  end

  defsynth tabla(%{bol: :tas} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.0133,
      modes: [
        {1.0002, -1.5, 0.34},
        {1.2098, 6.7, 0.129},
        {1.7796, 12.7, 2.027},
        {2.696, 3.2, 0.375},
        {3.557, 5.2, 0.261},
        {3.6364, 14.5, 0.256}
      ],
      noise: [
        {-90, 10.448},
        {-90, 2.321},
        {53.5, 0.12},
        {-90, 2.027},
        {48, 0.1},
        {-90, 0.259},
        {23.7, 0.465},
        {13.9, 0.546},
        {8.1, 0.248},
        {-2.0, 0.359},
        {-4.0, 0.299}
      ]
    )
    |> rings(seconds: 4)
  end

  defsynth tabla(%{bol: :ghe} = hit) do
    hit
    |> stroke(
      own: 42.25,
      level: 0.14,
      high: 3700,
      modes: [
        {1.0, 0.0, 3.528},
        {1.8376, -28.8, 5.735},
        {2.8494, -28.2, 1.599},
        {3.0246, -21.0, 1.599},
        {4.0406, -36.7, 0.874},
        {4.9808, -24.1, 0.553}
      ],
      noise: [
        {-90, 3.528},
        {-90, 5.727},
        {-90, 1.629},
        {-90, 0.553},
        {3.1, 0.433},
        {-5.5, 0.453},
        {-17.9, 1.63},
        {-25.6, 10.221},
        {-31.3, 12.0},
        {-38.9, 11.327},
        {-40.8, 12.0}
      ]
    )
    |> rings(seconds: 5)
  end

  defsynth tabla(%{bol: :ke} = hit) do
    hit
    |> stroke(
      own: 44.75,
      level: 0.081,
      modes: [{1.0, 0.0, 0.06}, {1.8376, -7.1, 0.05}, {2.8494, -10.0, 0.05}, {4.0406, -6.6, 0.04}],
      noise: [
        {-90, 0.05},
        {-90, 0.05},
        {-90, 0.05},
        {-90, 0.05},
        {18.9, 0.05},
        {10.3, 0.05},
        {4.1, 0.05},
        {-2.3, 0.05},
        {-5.4, 0.05},
        {-12.6, 0.05},
        {-23.2, 0.05}
      ]
    )
    |> rings(seconds: 0.1)
  end

  # The bands sit where they do at the bol's own pitch, and move with the note.
  defsoundp stroke(hit, shape) do
    freq = hz(hit.note || shape[:own])
    finger = lowpass(impulse(), hz: 3000)

    head =
      mix(
        for {ratio, level, ring} <- shape[:modes] do
          mode(finger, hz: freq * ratio, level: db(level), fade: ring)
        end
      )

    centres = List.replace_at(@bands, 7, Keyword.get(shape, :high, 2900))

    hiss =
      mix(
        for {centre, {level, fade}} <- Enum.zip(centres, shape[:noise]), level > -90 do
          noise(:white)
          |> bandpass(hz: centre * freq / hz(shape[:own]), q: 1 / 0.35, poles: 4)
          |> envelope([{0.001, 1}, {fade, 0.001, :exp}, {0.01, 0}])
          |> gain(db(level))
        end
      )

    (head + hiss)
    |> highshelf(hz: 1500, q: 1, db: (hit.vel - 0.6) * 5)
    |> gain(shape[:level] * (hit.vel / 0.6) ** 1.5)
  end
end
