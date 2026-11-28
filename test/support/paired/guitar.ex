defmodule Mx.Paired.Guitar do
  @moduledoc """
  mxs's guitar written with defsynth, playing its table as mxs does, so the two can be compared
  and timed.
  """

  use Mx.Paired.Tables,
    name: :guitar,
    play: :kept,
    level: 3.2,
    note: 52,
    release: 2.0
end
