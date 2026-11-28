defmodule Mix.Tasks.Mx.Samples.Download do
  @shortdoc "Downloads a collection of samples ahead of time"

  @moduledoc """
  Downloads a collection of samples into the user's cache, so songs play them with no network
  access.

      mx samples download sonic_pi
      mx samples download "vcsl:Idiophones/Struck Idiophones/Agogo Bells"
      mx samples download "owner/repo@v1.0:Samples"

  SOURCE is a collection mx knows by name, such as `sonic_pi` or `vcsl`, or a public GitHub
  repository as `owner/repo@ref`.
  Either is optionally followed by `:folder` to download only that folder; Sonic Pi's pack has no
  folders.
  Files already downloaded are skipped, so running it again finishes an interrupted download.
  The mx command does the same with `mx samples download SOURCE`.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    Mx.Command.config()

    case args do
      [source] ->
        case Mx.Samples.download_source(source) do
          {:ok, message} -> IO.puts(message)
          {:error, message} -> Mx.Command.fail(message)
        end

      _ ->
        Mx.Command.fail("usage: mix mx.samples.download SOURCE")
    end
  end
end
