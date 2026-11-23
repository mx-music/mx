defmodule Mx.Paired.Bassoon do
  @moduledoc """
  mxs's bassoon written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :bassoon,
    rate: 5.5,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 400.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 800.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.5,
      mend: 0.03,
      gasp: 0.0,
      jitter: 2.0,
      shimmer: 0.3,
      wander: 0.1
    },
    fit: %{
      gains: [
        [-5.6, -1.4, 2.3, 13.7, 3.1, 1.7, -0.1, 1.3, 2.3, 1.4, 0.8],
        [-8.4, -5.4, -0.1, 9.4, 1.4, 7.0, 2.2, 1.9, 3.5, 5.4, 4.1],
        [-10.0, -6.8, -1.2, 8.1, 0.8, 6.5, 3.5, 3.9, 6.1, 6.7, 4.3]
      ],
      levels: [-19.4, -5.7, -0.3],
      breath: [0.6, 0.62, 0.66],
      rise: [0.3, 0.15, 0.15],
      air: [-35.0, -50.0, -42.5],
      steep: [3.2, 3.2, 3.2],
      sharp: [[8.7327, 0.0, 0.0], [7.517, 0.0, 0.0], [5.1921, 0.0, 0.0]],
      lift: -4.6
    }
end
