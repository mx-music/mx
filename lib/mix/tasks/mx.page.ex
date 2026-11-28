defmodule Mix.Tasks.Mx.Page do
  @shortdoc "Writes a song as an HTML page that plays it and shows its parts"

  @moduledoc """
  Writes a song file as one HTML page, which plays the song's render and shows each part's notes
  on a timeline.

      mx page song.exs
      mx page song.exs --out song.html --title "A song" --seconds 60

  The page is written beside the song with the extension .html unless `--out` names it, and
  `--force` writes over a file that exists.
  `--seconds` is how long to render a song whose music does not end.
  The song's sound is encoded with ffmpeg, which has to be installed.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    strict = [out: :string, title: :string, seconds: :float, force: :boolean]
    {opts, [path]} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".html" end)
    Mx.Command.start()

    case Mx.Page.write(path, out, Keyword.take(opts, [:title, :seconds, :force])) do
      :ok -> Mx.Command.info("Wrote #{out}.")
      {:error, message} -> Mx.Command.fail(message)
    end
  end
end
