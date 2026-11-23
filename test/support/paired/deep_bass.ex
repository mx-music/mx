defmodule Mx.Paired.DeepBass do
  @moduledoc """
  mxs's deep bass written with defsynth, playing its table as mxs does, so the two can be compared and timed.
  """

  use Mx.Paired.Tables,
    name: :deep_bass,
    play: :fitted,
    level: 0.398,
    growth: 0.5,
    note: 33,
    release: 0.1
end
