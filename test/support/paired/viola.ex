defmodule Mx.Paired.Viola do
  @moduledoc """
  mxs's viola written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Bowed,
    name: :viola,
    pluck: %{
      peak: 350,
      rise: 17,
      soft_rise: 3,
      fall: 14,
      soft_fall: 4.5,
      fade: 3.7,
      fade_slope: -0.7,
      pluck: 0.13,
      gain: 0.3,
      count: 32,
      level: -15
    },
    fit: %{
      body: 367.1,
      gains: [
        [0.0, 9.3, 8.8, -6.2, 7.6, -0.8, 10.4, 3.7],
        [0.0, 13.2, 6.4, -4.6, 10.4, -0.7, 15.3, 0.5],
        [0.0, 12.7, 11.2, -6.2, 8.0, 2.4, 17.0, 1.7]
      ],
      levels: [-21.45, -29.20, -35.05],
      swell: [0.815, 0.68, 0.5],
      rosin: [0.1, 0.1, 0.1],
      hiss: [-35.5, -35.5, -30.5]
    }
end
