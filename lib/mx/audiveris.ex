defmodule Mx.Audiveris do
  @moduledoc """
  Runs Audiveris, the optical music recognition program, on page images, and gathers the MusicXML it writes for each page into one score.

  mx runs Audiveris as a separate program and ships none of its code.
  It is looked for at the `:audiveris` path in mx's config, which the `AUDIVERIS` environment variable sets, then as `audiveris` on the path, then where its macOS installer puts it.
  """

  @mac "/Applications/Audiveris.app/Contents/MacOS/Audiveris"

  @doc "The path to the Audiveris program, or nil when it is not installed."
  def find do
    case Application.get_env(:mx, :audiveris) do
      nil -> System.find_executable("audiveris") || installed(@mac)
      path -> installed(path)
    end
  end

  defp installed(path) do
    if File.exists?(path), do: path
  end

  @doc """
  Recognizes each image, writing Audiveris's books and MusicXML into `dir`, and returns the MusicXML files written for each image in order, an empty list for an image with no music.
  """
  def recognize(program, images, dir) do
    args = ["-batch", "-transcribe", "-export", "-output", dir, "--" | images]
    {log, status} = System.cmd(program, args, stderr_to_stdout: true)
    File.write!(Path.join(dir, "audiveris.log"), log)
    results = Enum.map(images, &scores(dir, &1))

    if status != 0 and Enum.all?(results, &(&1 == [])) and not Enum.any?(images, &book?(dir, &1)) do
      last = log |> String.split("\n", trim: true) |> Enum.take(-5) |> Enum.join("\n")
      {:error, "Audiveris failed:\n#{last}"}
    else
      {:ok, results}
    end
  end

  # Audiveris names a page's MusicXML after the image, and numbers the movements when a page holds more than one.
  defp scores(dir, image) do
    base = Path.rootname(Path.basename(image))

    dir
    |> File.ls!()
    |> Enum.filter(
      &(&1 == base <> ".mxl" or Regex.match?(~r/^#{Regex.escape(base)}\.mvt\d+\.mxl$/, &1))
    )
    |> Enum.sort_by(&movement/1)
    |> Enum.map(&Path.join(dir, &1))
  end

  defp movement(file) do
    case Regex.run(~r/\.mvt(\d+)\.mxl$/, file) do
      [_, number] -> String.to_integer(number)
      nil -> 0
    end
  end

  defp book?(dir, image) do
    File.exists?(Path.join(dir, Path.rootname(Path.basename(image)) <> ".omr"))
  end

  @doc """
  Joins the scores of several pages into one, appending each page's measures to the part at the same position on the first page.
  A part a page lacks, or reads fewer bars of, gets empty measures there, so the parts stay in step.

  Returns `{xml, bars, parts}`, with the number of bars and of parts read from each score.
  """
  def merge([_ | _] = paths) do
    pages = Enum.map(paths, &page/1)
    [%{head: head, tail: tail} | _] = pages
    count = length(hd(pages).parts)

    parts =
      for index <- 0..(count - 1) do
        {id, _measures} = Enum.at(hd(pages).parts, index)

        measures =
          pages
          |> Enum.flat_map(fn page ->
            measures = page.parts |> Enum.at(index, {nil, []}) |> elem(1)

            measures ++
              List.duplicate("<measure number=\"\"></measure>", bars(page) - length(measures))
          end)
          |> Enum.with_index(1)
          |> Enum.map_join("\n", fn {measure, number} -> renumber(measure, number) end)

        ~s(<part id="#{id}">\n#{measures}\n</part>)
      end

    {head <> Enum.join(parts, "\n") <> tail, Enum.map(pages, &bars/1),
     Enum.map(pages, &length(&1.parts))}
  end

  defp bars(page), do: page.parts |> Enum.map(&length(elem(&1, 1))) |> Enum.max(fn -> 0 end)

  defp page(path) do
    {:ok, xml} = Mx.Score.xml(path)
    xml = clean_names(xml)
    [head | _] = String.split(xml, ~r/<part id=/, parts: 2)
    [_ | tails] = String.split(xml, "</part>")
    tail = List.last(tails)

    parts =
      for [_, id, body] <- Regex.scan(~r/<part id="([^"]+)">(.*?)<\/part>/s, xml) do
        {id, Regex.scan(~r/<measure\b[^>]*>.*?<\/measure>/s, body) |> List.flatten()}
      end

    %{head: head, tail: tail, parts: parts}
  end

  defp renumber(measure, number) do
    Regex.replace(~r/^<measure number="[^"]*"/, measure, ~s(<measure number="#{number}"))
  end

  # Audiveris reads a part's name with the dots and stray marks around it, such as "' Tenore.".
  defp clean_names(xml) do
    Regex.replace(~r/<part-name>([^<]*)<\/part-name>/, xml, fn _, name ->
      clean =
        name
        |> unescape()
        |> String.replace(~r/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/u, "")
        |> escape()

      "<part-name>#{clean}</part-name>"
    end)
  end

  defp unescape(text) do
    Enum.reduce(
      [{"&apos;", "'"}, {"&quot;", "\""}, {"&lt;", "<"}, {"&gt;", ">"}, {"&amp;", "&"}],
      text,
      fn {from, to}, text ->
        String.replace(text, from, to)
      end
    )
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc "Writes MusicXML text as a compressed .mxl file."
  def write_mxl(path, xml) do
    container = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container><rootfiles><rootfile full-path="score.xml" media-type="application/vnd.recordare.musicxml+xml"/></rootfiles></container>
    """

    files = [{~c"META-INF/container.xml", container}, {~c"score.xml", xml}]
    {:ok, {_name, zip}} = :zip.create(~c"score.mxl", files, [:memory])
    File.write!(path, zip)
  end
end
