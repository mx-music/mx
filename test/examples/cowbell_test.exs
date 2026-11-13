defmodule Mx.Examples.CowbellTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/cowbell.exs"

  test "the solo plays only the two bells" do
    for pass <- 0..16 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert List.flatten(loops) == ["campana", "contracampana"]
    end

    refute print(0) =~ "sample "
  end

  test "the second gear plays closed strokes on the 2 side and two hard open strokes on the 3 side" do
    assert strokes(0, "campana") == [
             {0, "vel: 0.6, muted: 1"},
             {3.5, "vel: 0.6, muted: 1"},
             {4, "vel: 1"},
             {5.5, "vel: 1"},
             {7.5, "vel: 0.6, muted: 1"}
           ]

    assert strokes(0, "contracampana") == []
  end

  test "the third gear is open on each half bar and closed between, with a rest on the 2 side's second beat" do
    open = for {beat, opts} <- strokes(2, "campana"), not (opts =~ "muted"), do: beat
    closed = for {beat, opts} <- strokes(2, "campana"), opts =~ "muted", do: beat
    assert open == [0, 2, 4, 6]
    assert closed == [1, 3, 3.5, 5, 5.5, 7, 7.5]
  end

  test "the contracampana plays its pattern a fourth above, alone and then against the campana" do
    pattern = [0, 1, 2, 2.5, 3, 3.5, 4.5, 5, 5.5, 6, 7, 7.5]

    assert print(4) =~
             ~r/contracampana, pass 4, [^\n]*\nbeat 0 +play vel: 1, amp: 0.3, note: 75\n/

    assert for({beat, _} <- strokes(4, "contracampana"), do: beat) == pattern
    assert strokes(4, "campana") == []

    assert for({beat, _} <- strokes(6, "contracampana"), do: beat) == pattern
    assert strokes(6, "campana") == strokes(2, "campana")

    changuito = for {beat, _} <- strokes(10, "contracampana"), do: beat
    assert changuito == [0.5, 1, 2.5, 3, 3.5, 4.5, 5, 5.5, 6.5, 7, 7.5]
  end

  test "the campana plays the standard pattern of 12/8 twice to a pass, and both bells end on one hard open stroke" do
    standard = for {beat, _} <- strokes(12, "campana"), do: beat
    pulses = [0, 2, 4, 5, 7, 9, 11]
    assert standard == for(half <- [0, 4], pulse <- pulses, do: round3(half + pulse / 3))

    assert strokes(16, "campana") == [{0, "vel: 1"}]
    assert strokes(16, "contracampana") == [{0, "vel: 1"}]
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/cowbell.exs"
    assert File.read!("LICENSE-designs.md") =~ "cowbell recordings"
  end

  # One bell's strokes in a pass, as {beat, options}, without the bell's level and tuning.
  defp strokes(pass, bell) do
    [lines] =
      Regex.run(~r/^#{bell}, pass [^\n]*\n((?:beat [^\n]*\n)*)/m, print(pass),
        capture: :all_but_first
      )

    for [beat, opts] <-
          Regex.scan(~r/^beat ([\d.]+) +play (.*?), amp: /m, lines, capture: :all_but_first) do
      {number, _} = Float.parse(beat)
      {round3(number), opts}
    end
  end

  defp round3(number) do
    if number == trunc(number), do: trunc(number), else: Float.round(number / 1, 3)
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
      Mix.Tasks.Mx.Play.run([@song, "--record", out])
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
