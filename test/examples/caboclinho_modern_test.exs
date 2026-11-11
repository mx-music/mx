defmodule Mx.Examples.CaboclinhoModernTest do
  # Not async: it loads caboclinho.exs, whose module two loads at once cannot both define.
  use ExUnit.Case

  import ExUnit.CaptureIO

  @song "examples/caboclinho_modern.exs"
  @terno "examples/caboclinho.exs"

  # The first pass of each toque: guerra, perré, baião and macumba do índio.
  @toques [guerra: {0, 1}, perre: {2, 1.5}, baiao: {4, 1.25}, macumba: {6, 1.25}]

  test "the terno plays with a drum kit, a bass and a pad on mx's synths, and no samples" do
    assert {:ok, song} = Mx.Song.load(@song)

    assert Enum.sort(Enum.map(song.loops, &{&1.name, &1.synth})) ==
             Enum.sort(
               flute: :flute,
               ganza: :ganza,
               shaker: :shaker,
               low_bongo: :low_bongo,
               high_bongo: :high_bongo,
               cajon: :cajon,
               kick: :kick,
               snare: :snare,
               hihat: :closed_hihat,
               bass: :saw,
               pad: :supersaw
             )

    refute Enum.map_join(0..7, &print(@song, &1)) =~ "sample "
  end

  test "the gaita plays as in caboclinho.exs, and the terno strikes on the same beats, in every toque" do
    for {_toque, {pass, _unit}} <- @toques do
      assert loop_part(print(@song, pass), "flute") == loop_part(print(@terno, pass), "flute")

      for loop <- ~w(ganza shaker low_bongo high_bongo cajon) do
        assert beats(@song, pass, loop) == beats(@terno, pass, loop)
      end
    end
  end

  test "the kick starts every bar and the snare strikes every second beat, outside macumba do índio" do
    for {_toque, {pass, unit}} <- Enum.take(@toques, 3) do
      kicks = beats(@song, pass, "kick")
      snares = beats(@song, pass, "snare")

      for bar <- 0..7 do
        assert Float.round(bar * 2 * unit / 1, 3) in kicks
        assert Float.round((bar * 2 + 1) * unit / 1, 3) in snares
      end
    end
  end

  test "in macumba do índio the snare and the hi-hat drop out and the bass wobbles, and nowhere else" do
    {pass, _unit} = @toques[:macumba]

    assert beats(@song, pass, "snare") == []
    assert beats(@song, pass, "hihat") == []
    assert loop_part(print(@song, pass), "bass") =~ ~r/^beat 0 +control mix: 1$/m

    for {_toque, {pass, _unit}} <- Enum.take(@toques, 3) do
      assert loop_part(print(@song, pass), "bass") =~ ~r/^beat 0 +control mix: 0$/m
    end
  end

  test "the parts play through the new effects" do
    output = print(@song, 0)

    for {loop, effect} <- [
          flute: "chorus",
          flute: "ping_pong",
          ganza: "bpf",
          shaker: "flanger",
          low_bongo: "compressor",
          high_bongo: "bitcrusher",
          bass: "rlpf",
          bass: "wobble",
          pad: "tremolo"
        ] do
      assert output =~ ~r/^#{loop}, pass 0, [^\n]*#{effect} \(/m
    end
  end

  test "the README points to the modern version" do
    assert File.read!("README.md") =~ "examples/caboclinho_modern.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the modern version records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "caboclinho_modern.wav")
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

  defp beats(song, pass, loop) do
    for line <- String.split(loop_part(print(song, pass), loop), "\n"),
        [_, beat] <- [Regex.run(~r/^beat ([\d.]+) +play/, line)],
        do: Float.round(elem(Float.parse(beat), 0), 3)
  end

  defp print(song, pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([song, "--pass", pass]) end)
  end

  defp loop_part(output, loop) do
    case output |> String.split(~r/^#{loop}, pass \d+[^\n]*\n/m) |> tl() do
      [part | _] -> part |> String.split("\n") |> Enum.take_while(&(&1 != "")) |> Enum.join("\n")
      [] -> ""
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

  defp peak(wav) do
    <<"RIFF", _::32, "WAVE", chunks::binary>> = File.read!(wav)
    [_, <<size::little-32, data::binary>>] = :binary.split(chunks, "data")
    data = binary_part(data, 0, min(size, byte_size(data)))
    full = 8_388_608
    Enum.max(for <<sample::signed-little-24 <- data>>, do: abs(sample) / full)
  end
end
