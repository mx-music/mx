defmodule Mx.Examples.OdeonTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/odeon.exs"

  test "the regional plays the strain on winds, strings and pandeiro, and no samples" do
    output = Enum.map_join(0..1, &print/1)

    for loop <-
          ~w(trombone cello flute tenor_sax guitar cavaquinho pandeiro_thumb pandeiro_jingles pandeiro_heel shaker) do
      assert output =~ ~r/^#{loop}, pass \d+, 32 beats at 72 bpm/m
    end

    refute output =~ "sample "
  end

  test "the trombone and the flute play the strain, then the cello and the tenor saxophone repeat it" do
    for {pass, sings, answers, rests} <- [
          {0, "trombone", "flute", ~w(cello tenor_sax)},
          {1, "cello", "tenor_sax", ~w(trombone flute)}
        ] do
      output = print(pass)

      descent = [52, 51, 49, 47, 45, 44]
      assert notes(loop_part(output, sings)) |> Enum.take(12) |> Enum.uniq() == descent

      assert notes(loop_part(output, answers)) |> List.last() == 61
      for loop <- rests, do: assert(output =~ ~r/^#{loop}, pass \d+[^\n]*\n\n/m)
    end
  end

  test "the strokes swing off the sixteenth grid" do
    beats =
      Regex.scan(~r/^beat ([\d.]+)/m, loop_part(print(0), "shaker"), capture: :all_but_first)

    assert Enum.any?(beats, fn [beat] -> rem(round(elem(Float.parse(beat), 0) * 100), 25) != 0 end)
  end

  test "the README points to the demo" do
    assert File.read!("README.md") =~ "examples/odeon.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the demo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "odeon.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out, "--port", "57191"])
    after
      Process.group_leader(self(), leader)
    end

    assert peak(out) < 0.99
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end

  defp loop_part(output, loop) do
    [part | _] = output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl()
    part |> String.split("\n\n") |> hd()
  end

  defp notes(part) do
    for [note] <- Regex.scan(~r/play (\d+)/, part, capture: :all_but_first),
        do: String.to_integer(note)
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

  defp peak(wav) do
    <<"RIFF", _::32, "WAVE", chunks::binary>> = File.read!(wav)
    [_, <<size::little-32, data::binary>>] = :binary.split(chunks, "data")
    data = binary_part(data, 0, min(size, byte_size(data)))
    full = 8_388_608
    Enum.max(for <<sample::signed-little-24 <- data>>, do: abs(sample) / full)
  end
end
