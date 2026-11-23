defmodule Mx.Paired.Horn do
  @moduledoc """
  mxs's horn written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :horn,
    rate: 5.0,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 500.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 800.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.79,
      mend: 0.065,
      gasp: 0.0,
      jitter: 2.5,
      shimmer: 0.35,
      wander: 0.08
    },
    fit: %{
      gains: [
        [-4.0, 0.8, 4.5, 8.3, 4.7, 0.4, -3.7, -5.5, -3.9, -0.2, 1.1],
        [-9.2, -1.9, 4.4, 7.5, 5.3, 7.2, 4.7, -1.9, -1.6, 0.6, 1.1],
        [-12.8, -8.4, -1.7, 3.3, 1.2, 0.4, 7.5, 8.2, 7.5, 6.4, 3.1]
      ],
      levels: [-14.4, -9.7, 4.2],
      breath: [0.6, 0.62, 0.66],
      rise: [0.2, 0.25, 0.25],
      air: [-35.5, -35.5, -42.0],
      steep: [2.2, 3.2, 3.2],
      sharp: [[8.7341, 0.0, 0.0], [7.5077, 0.0, 0.0], [5.186, 0.0, 0.0]],
      lift: -5.56
    }
end
