defmodule Mx.Paired.DoubleBass do
  @moduledoc """
  mxs's double bass written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Bowed,
    name: :double_bass,
    pluck: %{
      peak: 84,
      rise: 24,
      soft_rise: 5,
      fall: 19.5,
      soft_fall: 2,
      fade: 3.9,
      fade_slope: 0,
      pluck: 0.13,
      gain: 0.6,
      count: 64,
      level: 0
    },
    fit: %{
      body: 67.5,
      gains: [
        [8.4, 4.1, -5.9, -6.8, -8.7, -3.0, -8.3, -3.0],
        [11.2, 5.1, -2.6, -3.4, -7.2, -0.0, -3.7, -9.4],
        [17.3, 8.1, -0.1, 1.2, -1.4, 3.5, 0.9, -0.7]
      ],
      levels: [-19.05, -24.20, -31.55],
      swell: [0.396, 0.342, 0.22],
      rosin: [0.3, 0.53, 0.1],
      hiss: [-35.5, -35.5, -30.5]
    }
end
