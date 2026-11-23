defmodule Mx.Paired.Tuba do
  @moduledoc """
  mxs's tuba written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :tuba,
    rate: 5.0,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 300.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 300.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.77,
      mend: 0.065,
      gasp: 0.0,
      jitter: 2.5,
      shimmer: 0.4,
      wander: 0.08
    },
    fit: %{
      gains: [
        [3.5, 5.5, 5.1, 3.1, 8.0, 2.8, -1.9, -0.7, 0.0, 0.1, 0.0],
        [-3.2, 3.8, 7.0, 5.5, 6.9, 4.8, 0.3, -0.1, 0.2, 0.5, 0.1],
        [-12.5, -4.3, -0.0, -0.3, 5.7, 8.8, 10.1, 8.6, 4.5, 1.3, 0.3]
      ],
      levels: [-23.9, -16.6, 0.7],
      breath: [0.6, 0.62, 0.66],
      rise: [0.25, 0.22, 0.18],
      air: [-30.0, -30.0, -36.0],
      steep: [2.2, 3.2, 3.2],
      sharp: [[8.7129, 0.0, 0.0], [7.4601, 0.0, 0.0], [5.1423, 0.0, 0.0]],
      lift: -3.93
    }
end
