defmodule Mx.Paired.ElectricPiano do
  @moduledoc """
  mxs's electric piano written with defsynth, playing its table as mxs does, so the two can be compared and timed.
  """

  use Mx.Paired.Tables,
    name: :electric_piano,
    play: :fitted,
    level: 0.168,
    growth: 0.4,
    note: 60,
    release: 0.15
end
