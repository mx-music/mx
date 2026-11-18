defmodule Mx.BenchTest do
  use ExUnit.Case, async: true

  alias Mx.Bench

  @moduletag :tmp_dir

  describe "worse/2" do
    test "a lead shorter by more than a tenth is worse, and one shorter by less is not" do
      before = %{"lead/idle/least_lead_ms" => 490.0, "lead/vm_busy/least_lead_ms" => 318.0}
      now = %{"lead/idle/least_lead_ms" => 400.0, "lead/vm_busy/least_lead_ms" => 300.0}
      assert Bench.worse(before, now) == [{"lead/idle/least_lead_ms", 490.0, 400.0}]
    end

    test "any other figure is worse when it is larger by more than a tenth" do
      before = %{"buffers/choro.exs/worst_percent" => 13.5, "saves/longest_gap_ms" => 250.0}
      now = %{"buffers/choro.exs/worst_percent" => 14.0, "saves/longest_gap_ms" => 300.0}
      assert Bench.worse(before, now) == [{"saves/longest_gap_ms", 250.0, 300.0}]
    end

    test "a figure that was 0 is worse once it is above 0" do
      assert Bench.worse(%{"lead/idle/late" => 0.0}, %{"lead/idle/late" => 1}) == [
               {"lead/idle/late", 0.0, 1}
             ]

      assert Bench.worse(%{"lead/idle/late" => 0.0}, %{"lead/idle/late" => 0}) == []
    end

    test "a figure in only one of the two is left out" do
      assert Bench.worse(%{"a" => 1.0}, %{"b" => 5.0}) == []
    end
  end

  test "figures written to a file are read back as they were", %{tmp_dir: dir} do
    path = Path.join(dir, "figures.txt")
    figures = %{"lead/idle/late" => 0, "lead/idle/least_lead_ms" => 491.8}
    Bench.write(path, figures)
    assert File.read!(path) == "lead/idle/late 0\nlead/idle/least_lead_ms 491.8\n"

    assert Bench.read(path) ==
             {:ok, %{"lead/idle/late" => 0.0, "lead/idle/least_lead_ms" => 491.8}}
  end

  test "a file that is not there is an error naming it", %{tmp_dir: dir} do
    path = Path.join(dir, "missing.txt")
    assert Bench.read(path) == {:error, "cannot read #{path}: no such file or directory"}
  end
end
