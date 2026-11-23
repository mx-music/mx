defmodule Mx.Ok do
  @moduledoc """
  Steps over a list whose every item may fail, as `{:ok, value}` or an error.
  """

  @doc "Each item through `fun`, as `{:ok, values}` in order, or the first result that is not `{:ok, value}`."
  def map(items, fun) do
    mapped =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, done} ->
        case fun.(item) do
          {:ok, value} -> {:cont, {:ok, [value | done]}}
          error -> {:halt, error}
        end
      end)

    case mapped do
      {:ok, done} -> {:ok, Enum.reverse(done)}
      error -> error
    end
  end
end
