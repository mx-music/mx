defmodule Mix.Tasks.Mx.Scan do
  @shortdoc "Reads the music on a scanned score into MusicXML"

  @moduledoc """
  Prepares the pages of a scanned score, reads the music on them with Audiveris or with a transcription model, and writes it as MusicXML beside the scan, ready for `mix mx.import`.

      mix mx.scan score.pdf --pages 3-4

  It reads a PDF, or a single page as a PNG, JPEG or TIFF image.
  `--pages` picks pages of a PDF, numbered as the PDF numbers them, such as `--pages 3-4` or `--pages 5`.
  `--raw` gives Audiveris the pages as they are, without preparing them.
  `--model` reads the music with the transcription model of `Mx.Transcriber` instead of Audiveris: it cuts each prepared page into its systems and transcribes them one by one, which suits printed piano music and degraded copies better than Audiveris.
  `--out` names another path for the MusicXML, and `--force` writes over one that exists.

  The prepared pages, and Audiveris's books of them or the systems and the ABC the model wrote for each, go in a folder beside the MusicXML.
  See documentation/audiveris.md for installing Audiveris.
  """

  use Mix.Task

  alias Mx.{ABC, Audiveris, Scan, Transcriber}
  alias Vix.Vips.{Image, Operation}

  @compile {:no_warn_undefined, [Image, Operation]}

  @dpi 300

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} =
      OptionParser.parse!(args,
        strict: [out: :string, pages: :string, raw: :boolean, model: :boolean, force: :boolean]
      )

    if not Code.ensure_loaded?(Image), do: Mix.raise(missing_dep(:vix, "~> 0.43"))
    out = Keyword.get(opts, :out, Path.rootname(path) <> ".mxl")
    if not File.regular?(path), do: Mix.raise("cannot read #{path}")
    pdf = String.downcase(Path.extname(path)) == ".pdf"
    pages = if pdf, do: pages(opts[:pages], page_count(path), path), else: [1]

    if File.exists?(out) and not Keyword.get(opts, :force, false) do
      Mix.raise("#{out} already exists; give --force to write over it")
    end

    raw = Keyword.get(opts, :raw, false)
    dir = Path.rootname(out) <> "-pages"

    if Keyword.get(opts, :model, false) do
      if raw, do: Mix.raise(raw_with_model())
      if not Code.ensure_loaded?(Pythonx), do: Mix.raise(missing_dep(:pythonx, "~> 0.4.11"))
      images = write_pages(path, pdf, pages, false, dir)
      transcribe(images, path, out, dir)
    else
      program = Audiveris.find() || Mix.raise(missing())
      images = write_pages(path, pdf, pages, raw, dir)
      read_with_audiveris(program, images, path, out, dir)
    end
  end

  defp read_with_audiveris(program, images, path, out, dir) do
    pages = recognize(program, images, dir)
    scores = for {_image, scores} <- pages, score <- scores, do: score

    if scores == [], do: Mix.raise("found no music in #{path}")

    {xml, bars, parts} = Audiveris.merge(scores)
    Audiveris.write_mxl(out, xml)
    report(pages, Enum.zip(bars, parts))
    Mix.shell().info("Wrote #{out}, with the pages Audiveris read in #{dir}")
    Mix.shell().info(import_command(out))
  end

  defp transcribe(images, path, out, dir) do
    pages = for {page, file, info} <- images, do: {page, info, write_systems(file, page, dir)}
    systems = for {_page, _info, systems} <- pages, system <- systems, do: system

    if systems == [], do: Mix.raise("found no music in #{path}")

    count = length(systems)

    Mix.shell().info(
      "Transcribing #{count} systems; the first run installs Python and its packages and downloads the model"
    )

    abcs =
      case Transcriber.transcribe(systems) do
        {:ok, abcs} -> abcs
        {:error, message} -> Mix.raise(message)
      end

    for {system, abc} <- Enum.zip(systems, abcs),
        do: File.write!(Path.rootname(system) <> ".abc", abc)

    Audiveris.write_mxl(out, ABC.musicxml(abcs))

    for {page, info, systems} <- pages do
      Mix.shell().info("Page #{page}: " <> systems_line(info, length(systems)))
    end

    Mix.shell().info("Wrote #{out}, with the pages and the systems the model read in #{dir}")
    Mix.shell().info(import_command(out))
  end

  # Each system of a prepared page, written at the width the model reads best.
  defp write_systems(file, page, dir) do
    file
    |> load()
    |> Scan.systems()
    |> Enum.with_index(1)
    |> Enum.map(fn {system, index} ->
      number = index |> Integer.to_string() |> String.pad_leading(2, "0")
      path = Path.join(dir, "page-#{pad(page)}-system-#{number}.png")
      scale = Transcriber.width() / Image.width(system)
      :ok = system |> Operation.resize!(scale) |> Image.write_to_file(path)
      path
    end)
  end

  defp systems_line(_info, 0), do: "no music found"

  defp systems_line(info, count) do
    before = info.before
    after_ = info.after
    angle = abs(info.angle)

    "staff lines #{before} px apart, now #{after_}, straightened #{angle} degrees, #{count} systems"
  end

  defp raw_with_model do
    "--raw leaves the pages unprepared, and --model reads the systems of prepared pages; give one or the other"
  end

  defp recognize(program, images, dir) do
    case Audiveris.recognize(program, Enum.map(images, &elem(&1, 1)), dir) do
      {:ok, results} -> Enum.zip(images, results)
      {:error, message} -> Mix.raise(message)
    end
  end

  defp write_pages(path, pdf, pages, raw, dir) do
    File.mkdir_p!(dir)

    for page <- pages do
      {image, info} = page_image(path, pdf, page, raw)
      file = Path.join(dir, "page-#{pad(page)}.png")
      :ok = Image.write_to_file(image, file)
      {page, file, info}
    end
  end

  defp missing_dep(name, requirement) do
    dep = inspect({name, requirement})
    "mix mx.scan needs #{name}; add #{dep} to the deps in your mix.exs"
  end

  defp missing do
    "mix mx.scan needs Audiveris, the optical music recognition program; " <>
      "install it from https://github.com/Audiveris/audiveris/releases as documentation/audiveris.md describes, " <>
      "or name the program in the AUDIVERIS environment variable"
  end

  defp page_count(path) do
    program = System.find_executable("pdfinfo") || Mix.raise(poppler())

    case System.cmd(program, [path], stderr_to_stdout: true) do
      {info, 0} ->
        [_, count] = Regex.run(~r/^Pages:\s+(\d+)/m, info)
        String.to_integer(count)

      _error ->
        Mix.raise("cannot read #{path}")
    end
  end

  defp poppler do
    "mix mx.scan needs poppler's pdftoppm and pdfinfo to read PDFs; install poppler, such as with brew install poppler"
  end

  defp pages(nil, count, _path), do: Enum.to_list(1..count)

  defp pages(given, count, path) do
    {first, last} =
      case Regex.run(~r/^(\d+)(?:-(\d+))?$/, given) do
        [_, first] -> {String.to_integer(first), String.to_integer(first)}
        [_, first, last] -> {String.to_integer(first), String.to_integer(last)}
        nil -> Mix.raise("--pages takes a page or a range, such as --pages 5 or --pages 3-4")
      end

    cond do
      first < 1 or last < first ->
        Mix.raise("--pages takes a page or a range, such as --pages 5 or --pages 3-4")

      last > count ->
        Mix.raise("#{path} has #{count} pages, so it has no page #{last}")

      true ->
        Enum.to_list(first..last)
    end
  end

  defp page_image(path, false, _page, true), do: {Scan.gray(load(path)), nil}
  defp page_image(path, false, _page, false), do: Scan.prepare(load(path))
  defp page_image(path, true, page, true), do: {render(path, page, @dpi), nil}

  # A PDF page is rendered again at the resolution that puts its staff lines the wanted distance
  # apart, which reads better than enlarging the first rendering.
  defp page_image(path, true, page, false) do
    {image, info} = Scan.prepare(render(path, page, @dpi))

    case info.before do
      nil ->
        {image, info}

      before when abs(before - 20) <= 2 ->
        {image, info}

      before ->
        dpi = round(@dpi * 20 / before)
        {image, again} = Scan.prepare(render(path, page, dpi))
        {image, %{again | before: before}}
    end
  end

  defp load(path) do
    case Image.new_from_file(path) do
      {:ok, image} -> image
      {:error, _reason} -> Mix.raise("cannot read #{path}")
    end
  end

  defp render(path, page, dpi) do
    program = System.find_executable("pdftoppm") || Mix.raise(poppler())
    base = Path.join(System.tmp_dir!(), "mx-scan-#{System.unique_integer([:positive])}")
    number = Integer.to_string(page)

    args = [
      "-f",
      number,
      "-l",
      number,
      "-r",
      Integer.to_string(dpi),
      "-gray",
      "-png",
      "-singlefile",
      path,
      base
    ]

    case System.cmd(program, args, stderr_to_stdout: true) do
      {_output, 0} ->
        file = base <> ".png"
        {:ok, binary} = File.read(file)
        File.rm!(file)
        {:ok, image} = Image.new_from_buffer(binary)
        image

      _error ->
        Mix.raise("cannot read page #{page} of #{path}")
    end
  end

  defp pad(page), do: page |> Integer.to_string() |> String.pad_leading(3, "0")

  defp report(pages, counts) do
    first = counts |> List.first() |> elem(1)

    {lines, _counts} =
      Enum.map_reduce(pages, counts, fn {{page, _file, info}, scores}, counts ->
        {read, counts} = Enum.split(counts, length(scores))
        bars = read |> Enum.map(&elem(&1, 0)) |> Enum.sum()
        parts = read |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> first end)
        {"Page #{page}: " <> page_line(info, scores, bars) <> parts_note(parts, first), counts}
      end)

    for line <- lines, do: Mix.shell().info(line)
  end

  defp parts_note(parts, parts), do: ""

  defp parts_note(parts, first) do
    "; it has #{parts} parts where the first page read has #{first}, matched in order"
  end

  defp page_line(_info, [], _bars), do: "no music found"
  defp page_line(nil, _scores, bars), do: "#{bars} bars"

  defp page_line(info, _scores, bars) do
    before = info.before
    after_ = info.after
    angle = abs(info.angle)
    "staff lines #{before} px apart, now #{after_}, straightened #{angle} degrees, #{bars} bars"
  end

  defp import_command(out) do
    {:ok, score} = Mx.Score.read(out)
    names = score.parts |> Enum.map(& &1.name) |> Enum.uniq()
    parts = Enum.map_join(names, " ", &~s(--part "#{shell(&1)}=tri"))
    tempo = if score.tempo, do: "", else: " --tempo 60"
    "Import it with: mix mx.import #{out}#{tempo} #{parts}"
  end

  defp shell(text), do: String.replace(text, ~r/(["\\$`])/, "\\\\\\1")
end
