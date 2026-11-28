defmodule Mx.Paired.Glockenspiel do
  @moduledoc """
  mxs's glockenspiel written with defsynth, playing its table as mxs does, so the two can be
  compared and timed.
  """

  use Mx.Paired.Tables,
    name: :glockenspiel,
    play: :kept,
    level: 6.95,
    note: 52,
    release: 0.3
end
