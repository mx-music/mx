defmodule Mx.CLI do
  @moduledoc """
  The mx command: runs each mix mx task as `mx` and the task's name, with a space for each dot,
  such as `mx export` for `mix mx.export` and `mx samples download` for `mix mx.samples.download`.
  `mx song.exs` plays a song, as `mx play song.exs` does, and `mx help NAME` prints a command's
  documentation.
  A command runs its task's own code, through `Mx.Command`, so it takes the same arguments, prints
  the same output and fails with the same messages.
  An escript keeps its apps in one archive, where no NIF can be loaded, so it first unpacks the
  archive into a cache folder named by its contents and runs its apps from there.
  """

  @doc "Runs the command, and exits with status 1 when it fails."
  def main(argv) do
    unpack()
    {:ok, _apps} = Application.ensure_all_started(:mx)

    case run(argv) do
      0 -> :ok
      status -> System.halt(status)
    end
  end

  @doc "Runs the command `argv` names, and returns its exit status."
  def run(["help" | words]) when words != [] do
    words = Enum.flat_map(words, &String.split/1)

    case Map.fetch(commands(), words) do
      {:ok, module} ->
        words |> Enum.join(" ") |> help(module)
        0

      :error ->
        usage()
    end
  end

  def run([first | _rest] = argv) do
    cond do
      found = command(argv) ->
        call(found)

      String.ends_with?(first, ".exs") or String.starts_with?(first, "-") ->
        call({Mix.Tasks.Mx.Play, argv})

      true ->
        usage()
    end
  end

  def run([]), do: usage()

  # The command the first one or two words name, with the arguments after them.
  defp command(argv) do
    commands = commands()

    Enum.find_value([2, 1], fn count ->
      {words, args} = Enum.split(argv, count)
      module = length(words) == count && commands[words]
      module && {module, args}
    end)
  end

  defp call({module, args}) do
    module.run(args)
    0
  rescue
    error in [Mx.Command.Error, Mix.Error, OptionParser.ParseError] ->
      IO.puts(:stderr, Exception.message(error))
      1
  end

  # Each mix mx task by the words that name its command.
  defp commands do
    for module <- Application.spec(:mx, :modules),
        name = Atom.to_string(module),
        String.starts_with?(name, "Elixir.Mix.Tasks.Mx."),
        into: %{} do
      words = name |> String.replace_prefix("Elixir.Mix.Tasks.Mx.", "") |> String.split(".")
      {Enum.map(words, &Macro.underscore/1), module}
    end
  end

  defp usage do
    commands =
      Enum.sort(for {words, module} <- commands(), do: {Enum.join(words, " "), shortdoc(module)})

    width = commands |> Enum.map(&String.length(elem(&1, 0))) |> Enum.max()

    IO.puts(:stderr, "usage: mx COMMAND [ARGS], or mx song.exs to play a song
")

    for {name, doc} <- commands do
      IO.puts(:stderr, "  mx " <> String.pad_trailing(name, width) <> "  # " <> doc)
    end

    IO.puts(:stderr, "
mx help COMMAND prints a command's documentation.")
    1
  end

  defp shortdoc(module) do
    case List.keyfind(module.__info__(:attributes), :shortdoc, 0) do
      {:shortdoc, [doc]} -> doc
      _ -> ""
    end
  end

  # Prints a command's documentation as mix help prints its task's.
  defp help(name, module) do
    opts = [width: width(), enabled: IO.ANSI.enabled?()]

    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} ->
        IO.ANSI.Docs.print_headings(["mx " <> name], opts)
        IO.ANSI.Docs.print(doc, "text/markdown", opts)

      _ ->
        IO.puts("There is no documentation for mx #{name}")
    end
  end

  defp width do
    case :io.columns() do
      {:ok, width} -> min(width, 80)
      {:error, _} -> 80
    end
  end

  defp unpack do
    script = :escript.script_name() |> to_string() |> Path.expand()

    if File.regular?(script) do
      {:ok, sections} = script |> to_charlist() |> :escript.extract([])
      archive = Keyword.fetch!(sections, :archive)

      hash =
        :sha256
        |> :crypto.hash(archive)
        |> Base.url_encode64(padding: false)
        |> binary_part(0, 16)

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
