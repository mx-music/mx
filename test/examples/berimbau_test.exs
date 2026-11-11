defmodule Mx.Examples.BerimbauTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/berimbau.exs"

  test "the solo plays the berimbau alone" do
    for pass <- 0..37 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["berimbau"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "Angola is open on beat 1, the coin on 2, a rest on 3 and two quick buzzes on 4" do
    assert_strokes(strokes(0), [
      {0, :open, 0.85},
      {1, :coin, 0.68},
      {3, :buzz, 0.38},
      {3.25, :buzz, 0.5},
      {4, :open, 0.85},
      {5, :coin, 0.68},
      {7, :buzz, 0.38},
      {7.25, :buzz, 0.5}
    ])
  end

  test "each stroke moves a little off its beat and its vel, as a player's do, but a buzz pair keeps its spacing" do
    all = Enum.flat_map(0..11, &strokes/1)
    beats = Enum.map(all, &elem(&1, 0))
    refute Enum.all?(beats, &(&1 == Float.round(&1 * 4) / 4))
    assert all |> Enum.map(&elem(&1, 2)[:vel]) |> Enum.uniq() |> length() > 10

    for [{first, :buzz, _}, {second, :buzz, _}] <- Enum.chunk_every(all, 2, 1, :discard) do
      assert_in_delta second - first, 0.25, 0.001
    end
  end

  test "each variation takes the first bar and Angola comes back in the second" do
    angola = [{4, :open, 0.85}, {5, :coin, 0.68}, {7, :buzz, 0.38}, {7.25, :buzz, 0.5}]

    for pass <- [3, 6, 9] do
      assert_strokes(Enum.drop_while(strokes(pass), fn {beat, _, _} -> beat < 3.9 end), angola)
    end

    assert_strokes(Enum.take(strokes(6), 7), [
      {0, :open, 0.85},
      {0.5, :open, 0.72},
      {1, :open, 0.72},
      {1.5, :open, 0.72},
      {2, :open, 0.72},
      {2.667, :open, 0.72},
      {3.333, :buzz, 0.5}
    ])
  end

  test "São Bento Pequeno swaps Angola's open and coin strokes, and São Bento Grande fills its rest with an open stroke" do
    assert_strokes(Enum.take(strokes(12), 2), [{0, :coin, 0.8}, {1, :open, 0.72}])
    refute Enum.any?(strokes(12), fn {beat, _, _} -> abs(beat - 2) < 0.1 end)
    assert Enum.any?(strokes(18), fn {beat, kind, _} -> kind == :open and abs(beat - 2) < 0.1 end)
  end

  test "the roda plays Angola at the Commons recording's 119 bpm, speeds up to São Bento Grande, then calms in Benguela" do
    assert print(0) =~ "8 beats at 120 bpm"
    assert print(12) =~ "8 beats at 136 bpm"
    assert print(18) =~ "8 beats at 150 bpm"
    assert print(20) =~ "rising to 172 bpm"
    assert print(28) =~ "8 beats at 172 bpm"
    assert print(32) =~ "8 beats at 108 bpm"
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/berimbau.exs"
    assert File.read!("LICENSE-designs.md") =~ "Berimbau jam without caxixi"
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

  defp strokes(pass) do
    for [beat, opts] <-
          Regex.scan(~r/^beat (\S+)\s+play (.*)$/m, print(pass), capture: :all_but_first) do
      {opts, _} = Code.eval_string("[" <> opts <> "]")

      kind =
        cond do
          opts[:buzz] == 1 -> :buzz
          opts[:coin] == 1 -> :coin
          true -> :open
        end

      {elem(Float.parse(beat), 0), kind, opts}
    end
  end

  defp assert_strokes(strokes, expected) do
    assert length(strokes) == length(expected)

    for {{beat, kind, opts}, {want, want_kind, vel}} <- Enum.zip(strokes, expected) do
      assert kind == want_kind
      assert_in_delta beat, want, 0.051
      assert_in_delta opts[:vel], vel, 0.101
    end
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
