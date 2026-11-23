defmodule Mx.Paired.Trombone do
  @moduledoc """
  mxs's trombone written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :trombone,
    rate: 4.95,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 700.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 1000.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.67,
      mend: 0.065,
      gasp: 0.0,
      jitter: 2.0,
      shimmer: 0.35,
      wander: 0.05
    },
    fit: %{
      gains: [
        [-8.0, -1.3, 0.4, 3.9, 5.1, 6.1, -0.4, -0.5, 1.1, 2.2, 1.1],
        [-11.2, -7.3, -4.1, -0.9, 0.7, 5.4, 6.4, 10.2, 7.5, 2.8, 1.3],
        [-12.7, -13.2, -11.3, -7.0, -5.1, 0.7, 5.0, 8.6, 14.8, 16.7, 5.4]
      ],
      levels: [-21.9, -4.7, 12.0],
      breath: [0.6, 0.62, 0.66],
      rise: [0.3, 0.3, 0.25],
      air: [-37.0, -45.5, -50.0],
      steep: [2.2, 3.2, 3.2],
      sharp: [[8.7325, 0.0, 0.0], [7.5093, 0.0, 0.0], [5.1892, 0.0, 0.0]],
      lift: -7.77
    }
end
