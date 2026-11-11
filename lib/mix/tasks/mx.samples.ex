defmodule Mix.Tasks.Mx.Samples do
  @shortdoc "Downloads Sonic Pi's sample pack"

  @moduledoc """
  Downloads Sonic Pi's sample pack, which is under Creative Commons 0, with its licence.

      mix mx.samples

  The pack is kept outside the repository, in the user's cache.
  Samples already downloaded are skipped, so running it again finishes an interrupted download.
  """

  use Mix.Task

  alias Mx.Samples

  @impl true
  def run(args) when is_list(args) do
    Mix.Task.run("app.config")
    dir = Samples.dir()

    case Samples.download(dir: dir) do
      {:ok, 0} ->
        IO.puts("The sample pack is complete in #{dir}.")

      {:ok, count} ->
        IO.puts("Downloaded #{count} files to #{dir}, and the sample pack is complete.")

      {:error, file, reason, count} ->
        Mix.raise(
          "Could not download #{file}: #{reason}.\nThe #{count} files downloaded before it stay in #{dir}; run mix mx.samples again to finish."
        )
    end
  end
end
