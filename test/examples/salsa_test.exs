defmodule Mx.Examples.SalsaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/salsa.exs"

  test "the band plays clave, bass, piano, congas, cáscara, cowbell and horns, and no samples" do
    output = Enum.map_join(0..15, &print/1)

    for loop <- ~w(clave bass piano high_conga low_conga cascara cowbell horns) do
      assert output =~ ~r/^#{loop}, pass \d+, 16 beats/m
    end

    assert output =~ ~r/^cowbell, pass 6, .*\nbeat 0 +play amp/m
    refute output =~ "sample "
  end

  test "the piano and the horns each take a solo, which replays the same" do
    montuno = loop_part(print(2), "piano")
    piano_solo = loop_part(print(4), "piano")
    horn_solo = loop_part(print(8), "horns")

    assert piano_solo != montuno
    refute piano_solo =~ ~r/beat 0.5 +play \d+ .*\nbeat 0.5 +play/
    assert horn_solo =~ "control note:"
    assert print(4) == print(4)
    assert print(8) == print(8)
  end

  test "the congas play the tumbao: soft tips, a slap on two, and open tones on four, the second on the low drum every other bar" do
    groove = print(1)

    high = loop_part(groove, "high_conga")

    assert high =~
             ~r/\Apass 1, [^\n]*\nbeat 0 +play amp: 0.12, slap: 0.3\nbeat 0.5 +play amp: 0.12, slap: 0.3\nbeat 1 +play amp: 0.45, slap: 1\n(.*\n){4}beat 3.5 +play amp: 0.45, slap: 0\n/

    refute high =~ "beat 7.5 "

    assert loop_part(groove, "low_conga") =~
             ~r/\Apass 1, [^\n]*\nbeat 7.5 +play amp: 0.55\nbeat 15.5 +play amp: 0.55\z/
  end

  test "the clave plays son clave 2-3 across every two bars" do
    assert loop_part(print(1), "clave") =~
             ~r/\Apass 1, [^\n]*\nbeat 1 +play amp: 0.35\nbeat 2 +play amp: 0.35\nbeat 4 +play amp: 0.35\nbeat 5.5 +play amp: 0.35\nbeat 7 +play amp: 0.35\nbeat 9 +play amp: 0.35\nbeat 10 +play amp: 0.35\nbeat 12 +play amp: 0.35\nbeat 13.5 +play amp: 0.35\nbeat 15 +play amp: 0.35\z/
  end

  test "the examples guide points to the demo" do
    assert File.read!("documentation/examples.md") =~ "examples/salsa.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the demo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "salsa.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out])
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
    [part | _] = output |> String.split(~r/^#{loop}, /m) |> tl()
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
