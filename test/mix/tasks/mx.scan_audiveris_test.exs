defmodule Mix.Tasks.Mx.ScanAudiverisTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.{Import, Scan}

  # Five pages of the Bach-Gesellschaft's St Matthew Passion: a page of text, the chorale
  # "Bin ich gleich von dir gewichen", the recitative after it, and the page of text twice more,
  # from the public-domain scan at https://archive.org/details/bach-gesellschaft-ausgabe.
  @pdf "test/support/scans/bga4.pdf"
  @reference "examples/bin_ich_gleich/bwv244.40.mxl"

  @moduletag :audiveris
  @moduletag timeout: 600_000

  setup_all do
    dir = Path.join(System.tmp_dir!(), "mx-scan-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    out = Path.join(dir, "score.mxl")
    output = capture_io(fn -> Scan.run([@pdf, "--pages", "1-3", "--out", out]) end)
    %{scanned: out, output: output}
  end

  test "names the page holding only text as having no music, and still writes the others", ctx do
    assert ctx.output =~ "Page 1: no music found\n"
    assert ctx.output =~ ~r/^Page 2: .*, 16 bars$/m

    assert ctx.output =~
             ~r/^Page 3: .*, \d+ bars; it has 3 parts where the first page read has 5, matched in order$/m

    assert File.exists?(ctx.scanned)
  end

  test "prints each page's staff line spacing before and after, and the degrees it was straightened",
       ctx do
    assert ctx.output =~
             ~r/^Page 2: staff lines 15 px apart, now (19|20|21), straightened 0.0 degrees, 16 bars$/m
  end

  test "reads the pages asked for in their order", ctx do
    {:ok, score} = Mx.Score.read(ctx.scanned)

    [[chorale], [recitative]] =
      Regex.scan(~r/^Page [23]: .*, (\d+) bars/m, ctx.output, capture: :all_but_first)

    bars = String.to_integer(chorale) + String.to_integer(recitative)

    assert length(hd(score.parts).bars) == bars
    assert length(score.parts) == 5
  end

  test "writes the prepared pages as grayscale images to a folder beside the MusicXML", ctx do
    dir = Path.rootname(ctx.scanned) <> "-pages"

    for page <- ~w(001 002 003) do
      {:ok, image} = Vix.Vips.Image.new_from_file(Path.join(dir, "page-#{page}.png"))
      assert Vix.Vips.Image.bands(image) == 1
    end
  end

  test "prints the mix mx.import command with a --part for each part, which imports the score",
       ctx do
    [command] =
      Regex.run(~r/^Import it with: (mix mx\.import .*)$/m, ctx.output, capture: :all_but_first)

    args = command |> OptionParser.split() |> Enum.drop(2)

    assert Enum.count(args, &(&1 == "--part")) == 5

    song = Path.rootname(ctx.scanned) <> ".exs"
    import = capture_io(fn -> Import.run(args) end)

    assert import =~ "Wrote #{song}"
    assert length(Regex.scan(~r/^\s*part\(:/m, File.read!(song))) == 5
  end

  test "the chorale's notes match the Bach chorale it prints", ctx do
    {:ok, scanned} = Mx.Score.read(ctx.scanned)

    for {part, matched} <- matches(scanned, 16) do
      assert matched > 0.5, "#{part} matched #{matched}"
    end
  end

  test "a PNG of the chorale page gives the same notes as the PDF page, and --force writes over the file",
       ctx do
    png = Path.join(Path.dirname(ctx.scanned), "chorale")
    {_, 0} = System.cmd("pdftoppm", ~w(-f 2 -l 2 -r 400 -gray -png -singlefile #{@pdf} #{png}))
    out = Path.join(Path.dirname(ctx.scanned), "chorale.mxl")
    File.write!(out, "")

    capture_io(fn -> Scan.run([png <> ".png", "--out", out, "--force"]) end)

    {:ok, from_png} = Mx.Score.read(out)
    {:ok, from_pdf} = Mx.Score.read(ctx.scanned)
    assert notes(from_png, 16) == notes(from_pdf, 16)
  end

  test "the page with --raw matches no more notes than the prepared page", ctx do
    out = Path.join(Path.dirname(ctx.scanned), "raw.mxl")
    capture_io(fn -> Scan.run([@pdf, "--pages", "2", "--raw", "--out", out]) end)

    {:ok, raw} = Mx.Score.read(out)
    {:ok, prepared} = Mx.Score.read(ctx.scanned)
    raw = matches(raw, 16)

    for {part, matched} <- matches(prepared, 16) do
      assert raw[part] <= matched
    end
  end

  test "a PDF of text only is refused with found no music in and its path", ctx do
    out = Path.join(Path.dirname(ctx.scanned), "text.mxl")

    assert_raise Mix.Error, "found no music in #{@pdf}", fn ->
      capture_io(fn -> Scan.run([@pdf, "--pages", "4-5", "--out", out]) end)
    end
  end

  # The share of each part of the reference chorale's notes, in order, found in the best matching
  # part read.
  defp matches(scanned, bars) do
    {:ok, reference} = Mx.Score.read(@reference)

    Map.new(reference.parts, fn part ->
      wanted = part_notes(part, bars)
      found = scanned.parts |> Enum.map(&common(wanted, part_notes(&1, bars))) |> Enum.max()
      {part.name, found / length(wanted)}
    end)
  end

  defp notes(score, bars), do: Enum.map(score.parts, &part_notes(&1, bars))

  defp part_notes(part, bars) do
    for bar <- Enum.take(part.bars, bars),
        [voice | _] <- [bar.voices],
        group <- voice,
        note <- group.notes,
        not note.continues,
        do: {note.midi, group.length * 1.0}
  end

  # The length of the longest common subsequence.
  defp common(wanted, found) do
    found = List.to_tuple(found)

    wanted
    |> Enum.reduce(List.duplicate(0, tuple_size(found) + 1), fn note, previous ->
      previous = List.to_tuple(previous)

      {row, _left} =
        Enum.map_reduce(1..tuple_size(found)//1, 0, fn index, left ->
          length = common_length(note, found, previous, index, left)
          {length, length}
        end)

      [0 | row]
    end)
    |> List.last()
  end

  defp common_length(note, found, previous, index, left) do
    if elem(found, index - 1) == note do
      elem(previous, index - 1) + 1
    else
      max(elem(previous, index), left)
    end
  end
end
