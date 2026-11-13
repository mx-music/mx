defmodule Mx.Examples.CaboclinhoTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/caboclinho.exs"

  # G, the gaita's tonic in every toque.
  @tonic 7

  test "the terno plays flute, ganza, shaker, low_bongo, high_bongo and cajon, and nothing else" do
    output = Enum.map_join(0..7, &print/1)

    loops =
      ~r/^(\w+), pass \d+/m
      |> Regex.scan(output)
      |> Enum.map(&List.last/1)
      |> Enum.uniq()
      |> Enum.sort()

    assert loops == ~w(cajon flute ganza high_bongo low_bongo shaker)
    refute output =~ "sample "
  end

  test "the toques come in the order guerra, perré, baião and macumba do índio, then guerra again" do
    assert Enum.map(0..8, &toque/1) == [
             :guerra,
             :guerra,
             :perre,
             :perre,
             :baiao,
             :baiao,
             :macumba,
             :macumba,
             :guerra
           ]
  end

  test "the gaita plays a neutral third above its tonic in every toque, and never a minor or a major one" do
    for pass <- [0, 2, 4, 6] do
      intervals = for {_beat, line} <- events(pass, "flute"), do: interval(note(line))

      refute Enum.any?(intervals, &(&1 in [3.0, 4.0]))
      assert 3.5 in intervals
    end
  end

  test "the gaita plays one note at a time" do
    for pass <- [0, 2, 4, 6] do
      notes = events(pass, "flute")

      ends =
        for {beat, line} <- notes, do: beat + option(line, "sustain") + option(line, "release")

      starts = tl(Enum.map(notes, &elem(&1, 0))) ++ [pass_beats(pass)]

      for {ending, start} <- Enum.zip(ends, starts), do: assert(ending <= start + 1.0e-9)
    end
  end

  test "in guerra, the tarol strikes at the start of the bar and a dotted eighth later, and varies on the fourth bar" do
    bars = bars(0, "low_bongo", 1)

    for bar <- [0, 1, 2, 4, 5, 6] do
      assert Enum.map(Enum.at(bars, bar), &elem(&1, 0)) == [0.0, 0.75]
    end

    assert Enum.at(bars, 3) != Enum.at(bars, 0)
    assert Enum.at(bars, 7) != Enum.at(bars, 0)
  end

  test "the preacas strike once a bar in guerra and in perré, and twice a bar in baião" do
    assert Enum.map(bars(0, "high_bongo", 1), &length/1) == List.duplicate(1, 8)
    assert Enum.map(bars(4, "high_bongo", 1.25), &length/1) == List.duplicate(2, 8)
    assert Enum.map(bars(2, "high_bongo", 1.5), &length/1) == List.duplicate(1, 8)
  end

  test "the caracaxás play every sixteenth in every toque, louder on the third of each beat" do
    for {pass, unit} <- [{0, 1}, {2, 1.5}, {4, 1.25}, {6, 1.25}], loop <- ["ganza", "shaker"] do
      strokes = events(pass, loop)

      assert Enum.map(strokes, &elem(&1, 0)) == Enum.map(0..63, &Float.round(&1 * 0.25 * unit, 3))

      for chunk <- Enum.chunk_every(strokes, 4) do
        [first, second, third, fourth] = Enum.map(chunk, fn {_, line} -> option(line, "vel") end)
        assert third > Enum.max([first, second, fourth])
      end
    end
  end

  test "the atabaque plays only in macumba do índio, and the tarol rests there" do
    for pass <- [0, 2, 4], do: assert(events(pass, "cajon") == [])

    assert events(6, "cajon") != []
    assert events(6, "low_bongo") == []
  end

  test "guerra is the fastest toque" do
    sixteenth = fn pass ->
      pass
      |> events("ganza")
      |> Enum.take(2)
      |> Enum.map(&elem(&1, 0))
      |> then(fn [a, b] -> b - a end)
    end

    assert sixteenth.(0) < sixteenth.(2)
    assert sixteenth.(0) < sixteenth.(4)
  end

  test "the examples guide points to the demo" do
    assert File.read!("documentation/examples.md") =~ "examples/caboclinho.exs"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "a minute of the demo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "caboclinho.wav")
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

  defp toque(pass) do
    beats = pass_beats(pass)
    preacas = length(events(pass, "high_bongo"))
    atabaque = events(pass, "cajon") != []

    cond do
      atabaque -> :macumba
      beats == 16 and preacas == 8 -> :guerra
      beats == 24 and preacas == 8 -> :perre
      beats == 20 and preacas == 16 -> :baiao
    end
  end

  defp interval(note), do: Float.round(:math.fmod(note - @tonic + 120, 12), 2)

  # A pass's strokes on one loop split into its eight bars of 2/4, each stroke's beat counted from its bar in beats of the toque.
  defp bars(pass, loop, unit) do
    strokes = events(pass, loop)

    for bar <- 0..7 do
      for {beat, line} <- strokes, beat >= bar * 2 * unit, beat < (bar + 1) * 2 * unit do
        {Float.round(beat / unit - bar * 2, 4), line}
      end
    end
  end

  defp pass_beats(pass) do
    [_, beats] = Regex.run(~r/^flute, pass \d+, ([\d.]+) beats/m, print(pass))
    String.to_float(beats <> if(beats =~ ".", do: "", else: ".0"))
  end

  defp events(pass, loop) do
    for line <- String.split(loop_part(print(pass), loop), "\n"),
        [_, beat] <- [Regex.run(~r/^beat ([\d.]+)/, line)],
        do: {number(beat), line}
  end

  defp note(line) do
    [_, note] = Regex.run(~r/play ([\d.]+)/, line)
    number(note)
  end

  defp option(line, name) do
    [_, value] = Regex.run(~r/#{name}: ([\d.]+)/, line)
    number(value)
  end

  defp number(text), do: elem(Float.parse(text), 0)

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
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
