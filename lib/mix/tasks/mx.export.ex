defmodule Mix.Tasks.Mx.Export do
  @shortdoc "Writes a song as a MusicXML score"

  @moduledoc """
  Writes a song as a MusicXML score, one part of the score for each part of the song that plays notes, through the whole of its music once.

      mix mx.export song.exs
      mix mx.export song.exs --time 12/8 --key bm --out song.mxl

  The score is written beside the song with the extension .musicxml unless `--out` names it, compressed when that ends in .mxl, and `--force` writes over a file that exists.
  `--time` gives the time signature, 4/4 unless given, and `--key` the key its notes are spelled in, such as d, bm or fsm, C major unless given.
  `--title` gives the score's title, which is otherwise the song file's name.
  A part that plays no notes with a pitch, such as drums or samples, or that waits for input, is left out, and the task says so.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    strict = [out: :string, time: :string, key: :string, title: :string, force: :boolean]
    {opts, [path]} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".musicxml" end)
    Mix.Task.run("app.start")

    case Mx.MusicXML.write(path, out, Keyword.take(opts, [:time, :key, :title, :force])) do
      {:ok, report} ->
        Mix.shell().info("Wrote #{out}")

        for %{name: name, notes: notes, low: low, high: high} <- report.parts do
          Mix.shell().info("#{name}: #{notes} notes from #{low} to #{high}")
        end

        for {name, why} <- report.left_out do
          Mix.shell().info("#{name} is left out: #{why}")
        end

      {:error, message} ->
        Mix.raise(message)
    end
  end
end
