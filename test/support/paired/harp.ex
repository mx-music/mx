defmodule Mx.Paired.Harp do
  @moduledoc """
  mxs's harp written with defsynth, playing its table as mxs does, so the two can be compared and
  timed.
  """

  use Mx.Paired.Tables,
    name: :harp,
    play: :evened,
    level: 0.197,
    note: 52,
    release: 2.0
end
