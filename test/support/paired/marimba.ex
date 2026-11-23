defmodule Mx.Paired.Marimba do
  @moduledoc """
  mxs's marimba written with defsynth, playing its table as mxs does, so the two can be compared and timed.
  """

  use Mx.Paired.Tables,
    name: :marimba,
    play: :kept,
    level: 1.53,
    note: 52,
    release: 0.3
end
