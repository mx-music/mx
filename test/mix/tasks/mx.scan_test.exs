defmodule Mix.Tasks.Mx.ScanTest do
  # Not async: one test points mx at an Audiveris that is not there.
  use ExUnit.Case

  alias Mix.Tasks.Mx.Scan

  @pdf "test/support/scans/bga4.pdf"

  @moduletag :tmp_dir

  test "a missing file is refused with cannot read and its path", %{tmp_dir: dir} do
    missing = Path.join(dir, "missing.pdf")

    assert_raise Mix.Error, "cannot read #{missing}", fn -> Scan.run([missing]) end
  end

  test "a page past the end is refused with the PDF's page count", %{tmp_dir: dir} do
    out = Path.join(dir, "score.mxl")

    assert_raise Mix.Error, "#{@pdf} has 5 pages, so it has no page 9", fn ->
      Scan.run([@pdf, "--pages", "9", "--out", out])
    end
  end

  test "an existing MusicXML file is refused, naming it", %{tmp_dir: dir} do
    out = Path.join(dir, "score.mxl")
    File.write!(out, "")

    assert_raise Mix.Error, "#{out} already exists; give --force to write over it", fn ->
      Scan.run([@pdf, "--pages", "2", "--out", out])
    end
  end

  test "--raw with --model is refused, since the model reads the systems of a prepared page", %{
    tmp_dir: dir
  } do
    out = Path.join(dir, "score.mxl")

    assert_raise Mix.Error,
                 "--raw leaves the pages unprepared, and --model reads the systems of prepared pages; give one or the other",
                 fn -> Scan.run([@pdf, "--pages", "2", "--raw", "--model", "--out", out]) end
  end

  test "with Audiveris not installed, it is refused, saying where to get it", %{tmp_dir: dir} do
    out = Path.join(dir, "score.mxl")
    previous = Application.get_env(:mx, :audiveris)
    Application.put_env(:mx, :audiveris, Path.join(dir, "no-audiveris"))

    try do
      error = assert_raise Mix.Error, fn -> Scan.run([@pdf, "--pages", "2", "--out", out]) end
      assert error.message =~ "mix mx.scan needs Audiveris"
      assert error.message =~ "https://github.com/Audiveris/audiveris/releases"
    after
      Application.put_env(:mx, :audiveris, previous)
    end
  end
end
