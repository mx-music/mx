defmodule Mx.Paired.ElectricBass do
  @moduledoc """
  mxs's electric bass written with defsynth, playing its table as mxs does, so the two can be
  compared and timed.
  """

  use Mx.Paired.Tables,
    name: :electric_bass,
    play: :fitted,
    level: 0.544,
    growth: 0.5,
    note: 33,
    release: 0.1
end
