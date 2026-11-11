defmodule Mx.Examples.MidnightTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/midnight.exs"
  @loops ~w(tanpura organ chorus oboe harmonium piano piano_phase tabla_na tabla_tun tabla_te tabla_ghe clave guiro)

  test "the piece plays only mx's measured synths, and no samples" do
    output = Enum.map_join(0..18, &print/1)

    for loop <- @loops do
      assert output =~ ~r/^#{loop}, pass \d+, 16 beats/m
    end

    refute output =~ "sample "
  end

  test "the oboe plays only raga Darbari's notes on Sa F, and its andolan swings Ga and Dha down" do
    notes =
      for pass <- 0..18,
          [_, note] <-
            Regex.scan(~r/(?:play|control note:) ([\d.]+)/, loop_part(print(pass), "oboe")) do
        String.to_float(note)
      end

    steps = MapSet.new(notes, &Float.round(:math.fmod(&1 - 65 + 24, 12), 2))
    raga = MapSet.new([0.0, 2.04, 3.16, 4.98, 7.02, 8.14, 9.96])
    andolan = MapSet.new([2.56, 7.54])
    assert MapSet.subset?(steps, MapSet.union(raga, andolan))
    assert MapSet.subset?(raga, steps)
    assert MapSet.subset?(andolan, steps)
  end

  test "in the alap the harmonium answers only once the oboe has stopped" do
    for pass <- 0..3 do
      oboe = beats(loop_part(print(pass), "oboe"), "play")
      harmonium = beats(loop_part(print(pass), "harmonium"), "play")
      assert length(harmonium) == 3
      assert Enum.min(harmonium) > Enum.max(oboe)
    end
  end

  test "the tabla and the pianos wait for the gat, and the claves for the fast gat" do
    for pass <- 0..3, loop <- ~w(tabla_na tabla_ghe piano piano_phase clave guiro) do
      assert loop_part(print(pass), loop) == "", "pass #{pass} plays #{loop}"
    end

    refute loop_part(print(4), "tabla_na") == ""
    refute loop_part(print(4), "piano") == ""
    assert loop_part(print(4), "piano_phase") == ""
    assert loop_part(print(7), "clave") == ""
    refute loop_part(print(8), "clave") == ""
  end

  test "the second piano locks in a sixteenth further ahead every pass, and returns to unison in shanti" do
    for pass <- 5..16 do
      ahead = pass - 5
      lead = notes(loop_part(print(pass), "piano"))
      phase = notes(loop_part(print(pass), "piano_phase"))
      assert Enum.take(phase, 32) == lead |> Stream.cycle() |> Enum.slice(ahead, 32)
      assert length(phase) == 65
    end

    shanti = print(17)
    assert notes(loop_part(shanti, "piano")) == notes(loop_part(shanti, "piano_phase"))
  end

  test "the tihai's last Sa lands on the sam of shanti, with the tabla and the claves" do
    tihai = loop_part(print(16), "oboe")
    assert length(Regex.scan(~r/control note: 68\.16, note_slide: 0\.06/, tihai)) == 3

    shanti = print(17)
    assert loop_part(shanti, "oboe") =~ ~r/\Abeat 0 +play 65\.0 /
    assert beats(loop_part(shanti, "tabla_na"), "play") == [0.0]
    assert beats(loop_part(shanti, "clave"), "play") == [0.0]
  end

  test "the README points to the piece" do
    assert File.read!("README.md") =~ "examples/midnight.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the piece records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "midnight.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out, "--port", "57191"])
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

  defp loop_part(output, loop) do
    [part | _] = output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl()
    ("\n" <> part) |> String.split("\n\n") |> hd() |> String.trim()
  end

  defp beats(part, verb) do
    for [_, beat] <- Regex.scan(~r/^beat ([\d.]+) +#{verb}/m, part) do
      {beat, _} = Float.parse(beat)
      beat
    end
  end

  defp notes(part) do
    for [_, note] <- Regex.scan(~r/play ([\d.]+) /, part), do: note
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
