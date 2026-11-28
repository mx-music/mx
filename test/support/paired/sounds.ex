defmodule Mx.Paired.Sounds do
  @moduledoc """
  The helpers mxs's voices share, written with defsound so the twins can share them as the voices
  do.
  """

  use Mx.Instrument

  @doc "The pitch in Hz, gliding with note and bend."
  defsound pitch(o) do
    hz(follow(o.note) + follow(o.bend))
  end

  @doc """
  `sound` tilted by brightness 3 dB an octave either way of 0.5, from the pitch up, by four high
  shelves two octaves apart; at 0.5 their 0 dB leaves it as it is, where mxs passes it untouched.
  """
  defsound tilted(o, sound) do
    tilt = (follow(o.brightness) - 0.5) * 12
    pitch = pitch(o)

    Enum.reduce(0..3, sound, fn k, shelved ->
      highshelf(shelved, hz: min(pitch * (2 * 4 ** k), 18_000), q: 0.707, db: tilt)
    end)
  end

  @doc "A rise to full over `seconds`, though never over more than part of the note's sustain."
  defsound swell(o, seconds) do
    envelope([{max(min(seconds, o.sustain * 0.4), 1.0e-4), 1, -2}])
  end

  @doc """
  The value at `f` Hz of `values` at `centres`, straight between them on a scale of octaves, going
  on below the first for two bands.
  """
  defsound along(centres, values, f) do
    octave = log2(f)

    [centres, tl(centres), values, tl(values)]
    |> Enum.zip()
    |> Enum.with_index()
    |> Enum.reduce(hd(values), fn {{low, high, from, to}, index}, sum ->
      {low, high} = {:math.log2(low), :math.log2(high)}
      sum + (to - from) * clamp((octave - low) / (high - low), if(index == 0, do: -2, else: 0), 1)
    end)
  end
end
