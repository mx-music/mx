defmodule Mx.SignalTest do
  use ExUnit.Case, async: true

  alias Mx.Signal

  test "filter_loss is what the high-pass takes from a sine near its cutoff" do
    rate = 48_000
    sine = for index <- 0..(2 * rate - 1), do: :math.sin(2 * :math.pi() * 110 * index / rate)
    held = sine |> Signal.high_pass(rate, 82.5) |> Enum.slice(div(rate, 2), rate)
    assert_in_delta -Signal.db(Enum.max(held)), Signal.filter_loss(110, 82.5), 0.01
  end
end
