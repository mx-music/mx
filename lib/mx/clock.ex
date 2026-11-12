defmodule Mx.Clock do
  @moduledoc """
  The Unix time in microseconds mx plays against: the system's, or while a song renders offline, the time its render has reached.

  A render sets the time with `start_render/1` and moves it on with `advance/1`, so the band, its loops and the engine work out a song as they do when it plays, only as fast as the render goes.
  """

  @doc "The time now, in Unix microseconds."
  def now do
    case :persistent_term.get(__MODULE__, nil) do
      nil -> System.os_time(:microsecond)
      time -> :atomics.get(time, 1)
    end
  end

  @doc "Whether a song is rendering offline, so the time moves only as the render moves it."
  def rendering?, do: :persistent_term.get(__MODULE__, nil) != nil

  @doc "Stops following the system's time and holds the time at `start_us` until `advance/1` moves it."
  def start_render(start_us) when is_integer(start_us) do
    time = :atomics.new(1, [])
    :atomics.put(time, 1, start_us)
    :persistent_term.put(__MODULE__, time)
    :ok
  end

  @doc "Moves a render's time on to `at_us`."
  def advance(at_us) when is_integer(at_us) do
    :atomics.put(:persistent_term.get(__MODULE__), 1, at_us)
    :ok
  end

  @doc "Follows the system's time again."
  def stop_render do
    :persistent_term.erase(__MODULE__)
    :ok
  end
end
