defmodule Mx.Application do
  @moduledoc """
  Starts mx with an empty supervisor; each session starts its own processes.
  """

  use Application

  @impl true
  def start(_type, args) when is_list(args) do
    children = []
    opts = [strategy: :one_for_one, name: Mx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
