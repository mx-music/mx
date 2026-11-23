defmodule Mx.Paired.Clarinet do
  @moduledoc """
  mxs's clarinet written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :clarinet,
    rate: 5.0,
    bore: %{
      conical: false,
      corner: 2.0,
      cutoff: 1500.0,
      keep: 0.95,
      bell: 1500.0,
      bell_corner: 2.0,
      smooth: 0.0,
      zeta: 0.4,
      relative: true,
      air: 1500.0,
      tongue: 0.0,
      kick: 1.25,
      catch: 0.5,
      mend: 0.03,
      gasp: 0.0,
      jitter: 1.0,
      shimmer: 0.3,
      wander: 0.0
    },
    fit: %{
      gains: [
        [2.5, 1.0, -1.5, -1.2, -4.1, -1.5, 0.6, 3.0, 2.3, -1.0, -1.4],
        [1.1, 0.5, -0.5, 0.7, -1.1, -1.7, -1.9, 5.4, 2.0, -2.2, -1.8],
        [0.5, 1.4, -1.4, -0.1, 1.6, 0.6, -2.7, 0.5, 3.4, -2.0, -1.3]
      ],
      levels: [7.8, 9.6, 8.8],
      breath: [1.08, 1.3, 1.6],
      rise: [0.2, 0.1, 0.1],
      air: [-60.0, -60.0, -45.5],
      steep: [0.0, 0.0, 0.0],
      sharp: [[0.5561, -0.0234, -0.0005], [4.6487, 0.1855, -0.0036], [9.9079, 0.4126, -0.0097]],
      lift: -3.76
    }
end
