defmodule Mx.Examples.ChoroTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/choro.exs"

  test "the regional plays flute, strummed cavaquinho, guitar and pandeiro, and no samples" do
    output = Enum.map_join(0..7, &print/1)

    for loop <-
          ~w(flute cavaquinho guitar pandeiro_thumb pandeiro_jingles pandeiro_heel) do
      assert output =~ ~r/^#{loop}, pass \d+, 16 beats/m
    end

    assert loop_part(print(0), "cavaquinho") =~ ~r/^beat 0.025 +play/m
    refute output =~ "sample "
  end

  test "the form is A A B B A C C A, with B in the relative minor and C in the subdominant" do
    roots =
      for pass <- 0..7 do
        [_, note] = Regex.run(~r/^beat 0 +play (\d+)/m, loop_part(print(pass), "guitar"))
        rem(String.to_integer(note), 12)
      end

    assert roots == [7, 7, 4, 4, 7, 0, 0, 7]
  end

  test "a strain plays the same melody each time it comes round" do
    melody = loop_part(print(0), "flute")
    assert loop_part(print(1), "flute") == melody
    assert loop_part(print(4), "flute") == melody
    assert loop_part(print(2), "flute") != melody
  end

  test "the README points to the demo" do
    assert File.read!("README.md") =~ "examples/choro.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the demo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "choro.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out, "--port", "57190"])
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
