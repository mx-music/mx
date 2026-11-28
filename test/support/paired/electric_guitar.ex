defmodule Mx.Paired.ElectricGuitar do
  @moduledoc """
  mxs's electric guitar written with defsynth, playing its table as mxs does, so the two can be
  compared and timed.
  """

  use Mx.Paired.Tables,
    name: :electric_guitar,
    play: :fitted,
    level: 0.269,
    growth: 0.4,
    note: 52,
    release: 0.08
end
