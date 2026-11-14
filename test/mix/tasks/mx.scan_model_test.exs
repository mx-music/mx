defmodule Mix.Tasks.Mx.ScanModelTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Scan

  # The last page of Joplin's Maple Leaf Rag, engraved from the music21 corpus's encoding and
  # photographed.
  @page "test/support/scans/rag-photo-3.jpg"

  @moduletag :transcriber
  @moduletag timeout: 1_800_000

  setup_all do
    dir = Path.join(System.tmp_dir!(), "mx-scan-model-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    out = Path.join(dir, "rag.mxl")
    output = capture_io(fn -> Scan.run([@page, "--model", "--out", out]) end)
    %{out: out, output: output, dir: dir}
  end

  test "reads the page's systems with the model into one score of both staves", ctx do
    assert ctx.output =~
             ~r/^Page 1: staff lines \d+ px apart, now \d+, straightened [\d.]+ degrees, 2 systems$/m

    assert ctx.output =~ "Import it with: mix mx.import #{ctx.out}"

    {:ok, score} = Mx.Score.read(ctx.out)
    assert length(score.parts) == 2
    assert length(hd(score.parts).bars) == 13
  end

  test "keeps each system's image and the ABC the model wrote for it beside the pages", ctx do
    pages = Path.join(ctx.dir, "rag-pages")

    for system <- ~w(01 02) do
      {:ok, image} =
        Vix.Vips.Image.new_from_file(Path.join(pages, "page-001-system-#{system}.png"))

      assert Vix.Vips.Image.width(image) == Mx.Transcriber.width()
      assert File.read!(Path.join(pages, "page-001-system-#{system}.abc")) =~ "[V:1]"
    end
  end
end
