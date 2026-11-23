defmodule Mx.Paired.Oboe do
  @moduledoc """
  mxs's oboe written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :oboe,
    rate: 5.0,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 1000.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 1500.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.46,
      mend: 0.03,
      gasp: 0.0,
      jitter: 2.0,
      shimmer: 0.2,
      wander: 0.1
    },
    fit: %{
      gains: [
        [-1.8, -8.4, -6.6, -3.0, -1.3, 7.9, 0.1, 2.6, 5.3, 2.0, 3.2],
        [-1.3, -6.4, -6.4, -6.2, -3.3, 9.3, 3.0, 6.1, 3.9, -0.1, 1.8],
        [-1.2, -5.7, -7.3, -6.0, -3.7, 6.9, -2.3, 5.5, 5.8, 2.6, 3.0]
      ],
      levels: [-5.1, 2.5, 7.9],
      breath: [0.6, 0.62, 0.66],
      rise: [0.35, 0.25, 0.2],
      air: [-50.0, -60.0, -51.0],
      steep: [1.0, 1.5, 3.2],
      sharp: [[8.7797, 0.0, 0.0], [7.5615, 0.0, 0.0], [5.2375, 0.0, 0.0]],
      lift: -3.65
    }
end
