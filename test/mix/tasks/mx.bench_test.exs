defmodule Mix.Tasks.Mx.BenchTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Bench

  @moduletag :engine
  @moduletag :tmp_dir
  @moduletag timeout: 180_000

  defp rows(output) do
    output |> String.split("\n", trim: true) |> Enum.map(&String.split(&1, ","))
  end

  test "lead prints a row for each of the four loads, with no note late and a lead above 300 ms" do
    [header | loads] =
      rows(capture_io(fn -> Bench.run(["lead", "examples/choro.exs", "--seconds", "5"]) end))

    assert header == [
             "load",
             "notes",
             "late",
             "least_lead_ms",
             "least_later_lead_ms",
             "longest_call_ms",
             "held_ms"
           ]

    assert Enum.map(loads, &hd/1) == ["idle", "vm_busy", "saves", "os_busy"]

    # No part of examples/choro.exs reaches its second pass in five seconds.
    for [_load, notes, late, lead, later_lead, _call, _held] <- loads do
      assert later_lead == "0.0"
      assert String.to_integer(notes) > 100
      assert late == "0"
      assert String.to_float(lead) > 300
    end
  end

  test "saves prints a row for each second, one load for each save, and leaves the song as it was" do
    before = File.read!("examples/choro.exs")

    output =
      capture_io(fn ->
        Bench.run(["saves", "examples/choro.exs", "--seconds", "8", "--at", "2,4,6"])
      end)

    lines =
      output |> String.split("\n", trim: true) |> Enum.reject(&String.starts_with?(&1, "Loaded "))

    assert length(lines) == 1 + 8 + 1
    assert hd(lines) == "second,notes,late,longest_gap_ms,memory_mb,processes"

    assert ["loads by mx: 3", " described to the window after, ms: " <> waits] =
             String.split(List.last(lines), ";")

    assert length(String.split(waits, ", ")) == 3
    assert File.read!("examples/choro.exs") == before
  end

  test "buffers prints a row for each song, none filled slower than it lasts", %{tmp_dir: dir} do
    songs = ["examples/choro.exs", "examples/caboclinho.exs", "examples/afrobeat.exs"]
    figures = Path.join(dir, "buffers.txt")

    [header | songs_rows] =
      rows(
        capture_io(fn ->
          Bench.run(["buffers" | songs] ++ ["--seconds", "5", "--write", figures])
        end)
      )

    assert header == ["song", "buffers", "mean_percent", "worst_percent", "over"]
    assert Enum.map(songs_rows, &hd/1) == ["choro.exs", "caboclinho.exs", "afrobeat.exs"]

    for [_song, buffers, mean, worst, over] <- songs_rows do
      assert buffers == "469"
      assert String.to_float(mean) > 0
      assert String.to_float(worst) < 100
      assert over == "0"
    end

    assert {:ok, written} = Mx.Bench.read(figures)
    assert map_size(written) == 9
  end

  test "--compare prints nothing when no figure is worse, and names the figure when one is", %{
    tmp_dir: dir
  } do
    easy = Path.join(dir, "easy.txt")
    hard = Path.join(dir, "hard.txt")

    Mx.Bench.write(easy, %{
      "buffers/choro.exs/worst_percent" => 1000.0,
      "buffers/choro.exs/over" => 0
    })

    Mx.Bench.write(hard, %{"buffers/choro.exs/worst_percent" => 0.001})

    run = fn file ->
      capture_io(fn ->
        Bench.run(["buffers", "examples/choro.exs", "--seconds", "2", "--compare", file])
      end)
    end

    assert easy |> run.() |> String.split("\n", trim: true) |> length() == 2
    assert [_header, _row, worse] = String.split(run.(hard), "\n", trim: true)
    assert worse =~ ~r/^worse: buffers\/choro\.exs\/worst_percent was 0\.001 and is \d+\.\d$/
  end
end
