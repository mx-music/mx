defmodule Mx.Command do
  @moduledoc """
  What a command does differently when it runs as a Mix task and when the mx command runs it.
  The mx command carries no Mix, so each mix task reports, fails and starts mx through this module, and both run the same task code.
  Under Mix a failure is a `Mix.Error`, so `mix` prints it and exits with status 1; under the mx command it is an `Mx.Command.Error`, which the mx command prints the same way.
  """

  defmodule Error do
    @moduledoc "A command that cannot go on, with the message it prints."
    defexception [:message]
  end

  @doc "Stops the command with `message`."
  @spec fail(String.t()) :: no_return()
  def fail(message) when is_binary(message) do
    if mix?(), do: Mix.raise(message), else: raise(Error, message)
  end

  @doc "Prints `message` to standard output."
  def info(message) when is_binary(message) do
    if mix?(), do: Mix.shell().info(message), else: IO.puts(message)
  end

  @doc "Prints `message` to standard error."
  def error(message) when is_binary(message) do
    if mix?(), do: Mix.shell().error(message), else: IO.puts(:stderr, message)
  end

  @doc "Starts mx, which the mx command has already done."
  def start do
    if mix?(), do: Mix.Task.run("app.start")
    :ok
  end

  @doc "Loads mx's configuration without starting it, which the mx command has already done."
  def config do
    if mix?(), do: Mix.Task.run("app.config")
    :ok
  end

  defp mix?, do: Code.ensure_loaded?(Mix) and Process.whereis(Mix.State) != nil
end
