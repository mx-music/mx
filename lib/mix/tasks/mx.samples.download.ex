defmodule Mix.Tasks.Mx.Samples.Download do
  @shortdoc "Downloads a collection of samples ahead of time"

  @moduledoc """
  Downloads a collection of samples into the user's cache, so songs play them with no network access.

      mix mx.samples.download sonic_pi
      mix mx.samples.download "sgossner/VCSL@c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e:Idiophones/Struck Idiophones/Agogo Bells"

  SOURCE is `sonic_pi` for Sonic Pi's pack, which is under Creative Commons 0, or a public GitHub repository as `owner/repo@ref`, optionally followed by `:folder` to download only that folder.
  Files already downloaded are skipped, so running it again finishes an interrupted download.
  The mx command does the same with `mx samples download SOURCE`.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    Mix.Task.run("app.config")

    case args do
      [source] ->
        case Mx.Samples.download_source(source) do
          {:ok, message} -> IO.puts(message)
          {:error, message} -> Mix.raise(message)
        end

      _ ->
        Mix.raise("usage: mix mx.samples.download SOURCE")
    end
  end
end
