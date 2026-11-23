defmodule Mx.Paired.Xylophone do
  @moduledoc """
  mxs's xylophone written with defsynth, playing its table as mxs does, so the two can be compared and timed.
  """

  use Mx.Paired.Tables,
    name: :xylophone,
    play: :kept,
    level: 2.38,
    note: 52,
    release: 0.3
end
