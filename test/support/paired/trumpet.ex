defmodule Mx.Paired.Trumpet do
  @moduledoc """
  mxs's trumpet written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :trumpet,
    rate: 4.9,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 1200.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 1500.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.68,
      mend: 0.065,
      gasp: 0.0,
      jitter: 2.0,
      shimmer: 0.2,
      wander: 0.04
    },
    fit: %{
      gains: [
        [-4.7, -11.7, -4.7, -1.7, -1.3, 12.7, 11.1, 2.9, 0.2, -0.6, -0.1],
        [-3.2, -9.4, -7.8, -4.3, -2.3, 3.4, 5.5, 8.7, 4.1, 3.9, 1.8],
        [-3.8, -10.8, -10.0, -5.1, -5.0, 1.0, 2.8, 7.2, 6.3, 9.8, 4.3]
      ],
      levels: [0.9, 9.7, 13.3],
      breath: [0.6, 0.62, 0.66],
      rise: [0.35, 0.35, 0.2],
      air: [-60.0, -55.0, -55.0],
      steep: [1.0, 3.2, 3.2],
      sharp: [[8.7541, 0.0, 0.0], [7.5353, 0.0, 0.0], [5.2181, 0.0, 0.0]],
      lift: -9.31
    }
end
