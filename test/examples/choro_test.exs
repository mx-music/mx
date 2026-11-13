defmodule Mx.Examples.ChoroTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/choro.exs"

  test "the regional plays flute, clarinet, strummed cavaquinho, guitar and pandeiro, and no samples" do
    output = Enum.map_join(0..7, &print/1)

    for loop <-
          ~w(flute clarinet cavaquinho guitar pandeiro_thumb pandeiro_jingles pandeiro_heel pandeiro_slap) do
      assert output =~ ~r/^#{loop}, pass \d+, 32 beats/m
    end

    assert loop_part(print(0), "cavaquinho") =~ ~r/^beat 0.02 +play/m
    refute output =~ "sample "
  end

  test "the form is A A B B A C C A, with B in the relative minor and C in the subdominant" do
    roots =
      for pass <- 0..7 do
        [_, note] = Regex.run(~r/^beat 30 +play (\d+)/m, loop_part(print(pass), "guitar"))
        rem(String.to_integer(note), 12)
      end

    assert roots == [7, 7, 4, 4, 7, 0, 0, 7]
  end

  test "the flute opens on Nazareth's first bar, E D C# D F# E D C, with a mordent on the E" do
    assert Enum.take(notes(loop_part(print(0), "flute")), 10) == [
             76,
             78,
             76,
             74,
             73,
             74,
             78,
             76,
             74,
             72
           ]
  end

  test "a strain plays the same melody each time it comes round, up to its last bar" do
    melody = fn pass -> pass |> print() |> loop_part("flute") |> before(30) end

    assert melody.(4) == melody.(0)
    assert melody.(2) != melody.(0)
  end

  test "the clarinet takes the repeat of A while the flute waits for its pickup, and they play the last A an octave apart" do
    assert before(loop_part(print(1), "flute"), 31) == ""
    assert loop_part(print(0), "clarinet") == ""

    opening = notes(loop_part(print(0), "flute"))
    assert notes(loop_part(print(1), "clarinet")) |> Enum.take(100) == Enum.take(opening, 100)

    flute = for note <- notes(before(loop_part(print(7), "flute"), 30)), do: note - 12
    assert notes(before(loop_part(print(7), "clarinet"), 30)) == flute
  end

  test "the examples guide points to the demo" do
    assert File.read!("documentation/examples.md") =~ "examples/choro.exs"
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
    [part | _] = output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl()
    part |> String.split("\n\n") |> hd()
  end

  # Every pitch a part sounds, in order: the notes it plays and the notes its breaths change to.
  defp notes(part) do
    for [_, note] <- Regex.scan(~r/(?:play|control note:) (\d+)/, part),
        do: String.to_integer(note)
  end

  # A part's lines before a beat.
  defp before(part, beat) do
    part
    |> String.split("\n", trim: true)
    |> Enum.filter(fn line ->
      [_, at] = Regex.run(~r/^beat ([\d.]+)/, line)
      elem(Float.parse(at), 0) < beat
    end)
    |> Enum.join("\n")
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
