defmodule Mix.Tasks.Mx.LevelsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Levels

  @moduletag :tmp_dir
  @rate 48_000

  setup %{tmp_dir: dir} do
    path = Path.join(dir, "click.wav")
    samples = List.duplicate(0.0, @rate) ++ List.duplicate(0.5, 480) ++ List.duplicate(0.0, @rate)
    Mx.Audio.write(path, samples, @rate)
    %{path: path}
  end

  test "prints a line naming the columns, then one line for each row", %{path: path} do
    lines = String.split(capture_io(fn -> Levels.run([path]) end), "\n", trim: true)
    {:ok, rows} = Mx.Levels.rows(path)

    assert hd(lines) ==
             "seconds,level,20-40 Hz,40-80 Hz,80-160 Hz,160-320 Hz,320-640 Hz,640-1280 Hz,1280-2560 Hz,2560-5120 Hz,5120-10240 Hz,10240-20480 Hz,brightness"

    assert length(tl(lines)) == length(rows)
    assert lines |> Enum.at(1) |> String.split(",") |> length() == 13
  end

  test "--per-second sets the rows a second", %{path: path} do
    lines = capture_io(fn -> Levels.run([path, "--per-second", "10"]) end)
    assert lines |> String.split("\n", trim: true) |> length() == 1 + 21
  end

  test "--strokes prints the strokes in place of the rows", %{path: path} do
    [header, stroke] =
      String.split(capture_io(fn -> Levels.run([path, "--strokes"]) end), "\n", trim: true)

    assert header == "seconds,level"
    assert [at, "0.0"] = String.split(stroke, ",")
    assert_in_delta String.to_float(at), 1.0, 0.01
  end

  test "refuses a file that is not a recording", %{tmp_dir: dir} do
    path = Path.join(dir, "notes.txt")
    File.write!(path, "not a recording")
    assert_raise Mix.Error, "cannot read #{path}", fn -> Levels.run([path]) end
  end

  test "the guide to instruments describes mix mx.levels" do
    assert File.read!("documentation/instruments.md") =~ "mx levels"
  end
end
