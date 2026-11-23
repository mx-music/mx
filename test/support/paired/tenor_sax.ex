defmodule Mx.Paired.TenorSax do
  @moduledoc """
  mxs's tenor sax written with defsynth, node for node, so the two can be compared and timed.
  """

  use Mx.Paired.Reeds,
    name: :tenor_sax,
    rate: 4.94,
    bore: %{
      conical: true,
      corner: 2.0,
      cutoff: 0.0,
      keep: 0.95,
      bell: 800.0,
      bell_corner: 0.0,
      smooth: 2.0,
      zeta: 0.4,
      relative: false,
      air: 1500.0,
      tongue: 0.25,
      kick: 0.0,
      catch: 0.64,
      mend: 0.03,
      gasp: 0.0,
      jitter: 0.8,
      shimmer: 0.25,
      wander: 0.08
    },
    fit: %{
      gains: [
        [-4.5, -12.0, -5.2, -3.0, -0.5, -0.3, 2.9, 8.5, 5.6, 4.6, 2.8],
        [-10.8, -11.1, -2.3, 0.3, -5.5, -2.1, 3.9, 9.5, 9.9, 6.9, 4.7],
        [-9.8, -10.6, -3.8, -1.3, -8.3, -3.8, 1.8, 5.7, 7.6, 12.1, 7.8]
      ],
      levels: [0.3, 9.4, 12.9],
      breath: [0.6, 0.62, 0.66],
      rise: [0.01, 0.012, 0.006],
      air: [-54.5, -60.0, -58.0],
      steep: [1.0, 1.5, 3.2],
      sharp: [[8.7338, 0.0, 0.0], [7.5151, 0.0, 0.0], [5.1983, 0.0, 0.0]],
      lift: -7.47
    }
end
