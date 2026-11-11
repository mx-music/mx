defmodule Mx.Examples.CowbellTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/cowbell.exs"

  test "the solo plays only the cowbell" do
    for pass <- 0..8 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["cowbell"]]
    end

    refute print(0) =~ "sample "
  end

  test "the second gear plays closed strokes on the 2 side and two hard open strokes on the 3 side" do
    assert strokes(0) == [
             {0, "vel: 0.6, muted: 1"},
             {3.5, "vel: 0.6, muted: 1"},
             {4, "vel: 1"},
             {5.5, "vel: 1"},
             {7.5, "vel: 0.6, muted: 1"}
           ]

    assert strokes(6) == strokes(0)
  end

  test "the third gear is open on each half bar and closed between, with a rest on the 2 side's second beat" do
    open = for {beat, opts} <- strokes(2), not (opts =~ "muted"), do: beat
    closed = for {beat, opts} <- strokes(2), opts =~ "muted", do: beat
    assert open == [0, 2, 4, 6]
    assert closed == [1, 3, 3.5, 5, 5.5, 7, 7.5]
  end

  test "the solo ends on one hard open stroke" do
    assert strokes(8) == [{0, "vel: 1"}]
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/cowbell.exs"
    assert File.read!("LICENSE-designs.md") =~ "cowbell recordings"
  end

  defp strokes(pass) do
    for [beat, opts] <-
          Regex.scan(~r/^beat ([\d.]+) +play (.*), amp: 0.5$/m, print(pass),
            capture: :all_but_first
          ) do
      {number, _} = Float.parse(beat)
      {if(number == trunc(number), do: trunc(number), else: number), opts}
    end
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the solo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out, "--port", "57190"])
    after
      Process.group_leader(self(), leader)
    end

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end

  # An input device that answers the first line asked for after a delay, as a person pressing Enter would.
  defp enter_after(ms) do
    receive do
      {:io_request, from, ref, {:get_line, _, _}} ->
        Process.sleep(ms)
        send(from, {:io_reply, ref, "\n"})
        enter_after(ms)

      {:io_request, from, ref, _request} ->
        send(from, {:io_reply, ref, :ok})
        enter_after(ms)
    end
  end
end
