defmodule Mx.Paired.Timpani do
  @moduledoc """
  mxs's timpani written with defsynth, playing its table as mxs does, so the two can be compared
  and timed.
  """

  use Mx.Paired.Tables,
    name: :timpani,
    play: :kept,
    level: 1.03,
    note: 52,
    release: 0.3
end
