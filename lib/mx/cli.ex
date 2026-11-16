defmodule Mx.CLI do
  @moduledoc """
  The mx command: plays, records or renders a song file, or downloads a sample source.
  An escript keeps its apps in one archive, where no NIF can be loaded, so it first unpacks the archive into a cache folder named by its contents and runs its apps from there.
  """

  @usage """
  usage: mx song.exs [--record session.wav | --render song.wav [--seconds 60]] [--force]
         mx samples download SOURCE
  """

  @doc "Runs the command."
  def main(argv) do
    unpack()
    {:ok, _apps} = Application.ensure_all_started(:mx)
    run(argv)
  end

  defp run(["samples", "download", source]) do
    case Mx.Samples.download_source(source) do
      {:ok, message} -> IO.puts(message)
      {:error, message} -> fail(message)
    end
  end

  defp run(argv) do
    case Mx.Player.parse(argv) do
      {opts, [path]} ->
        case Mx.Player.play(path, opts) do
          :ok -> :ok
          {:error, message} -> fail(message)
        end

      _ ->
        IO.write(:stderr, @usage)
        System.halt(1)
    end
  end

  defp fail(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end

  defp unpack do
    script = :escript.script_name() |> to_string() |> Path.expand()

    if File.regular?(script) do
      {:ok, sections} = script |> to_charlist() |> :escript.extract([])
      archive = Keyword.fetch!(sections, :archive)

      hash =
        :crypto.hash(:sha256, archive) |> Base.url_encode64(padding: false) |> binary_part(0, 16)

      dir = Path.join(:filename.basedir(:user_cache, "mx"), "escript-" <> hash)

      if not File.dir?(dir) do
        partial = dir <> ".partial"
        File.rm_rf!(partial)
        {:ok, _files} = :zip.extract(archive, cwd: to_charlist(partial))
        File.rename!(partial, dir)
      end

      for path <- :code.get_path(),
          inside = path |> to_string() |> Path.expand(),
          String.starts_with?(inside, script <> "/") do
        :code.del_path(path)
        dir |> Path.join(Path.relative_to(inside, script)) |> to_charlist() |> :code.add_patha()
      end
    end
  end
end
