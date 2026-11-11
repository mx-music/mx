defmodule Mx.Examples.RagaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/raga.exs"
  @passes 0..15
  @gat 9..15

  # Page 33's sthayi and antara, one cell to each matra from khali, its main notes only: + joins the notes of one matra, _ holds within it, - holds the matra before and ~ glides into a note on the same pluck.
  @sthayi [
    ~w(S+R G+M P+D N+S' N+D P+M G+R S+S P - ~G M+P+D P R - R),
    ~w(S' S' - N+N P - M+P D+N S' R - P R .N R S)
  ]
  @antara [
    ~w(P - S' S' S' R' S' - S' R'+S' R' G'+R' S' N P P),
    ~w(S' S' - N+_+D+N P - M+P D+N S' R - P R .N R S)
  ]
  @steps %{0 => "S", 204 => "R", 386 => "G", 590 => "M", 702 => "P", 884 => "D", 1088 => "N"}

  # mx.print does not name a pass's section, so each is told by what plays: the gat has the tabla, the jor the chikari to a pulse, and the alap neither.
  test "the tanpura drones from the first beat to the last, through alap, jor and gat in turn" do
    assert print(0) =~ ~r/^tanpura, pass 0.*\nbeat 0 +play 49 vel: 0.5, gap: 1, sustain: 256,/m

    sections =
      for pass <- @passes do
        printed = print(pass)
        if pass > 0, do: refute(printed =~ ~r/^tanpura, pass \d+.*\nbeat/m)

        cond do
          printed =~ ~r/tabla_na, pass \d+.*\nbeat/ -> :gat
          printed =~ ~r/chikari, pass \d+.*\nbeat/ -> :jor
          true -> :alap
        end
      end

    assert Enum.dedup(sections) == [:alap, :jor, :gat]
    assert Enum.count(sections, &(&1 == :gat)) == 7
  end

  test "the alap and the jor play no tabla" do
    for pass <- 0..8, synth <- ~w(tabla_na tabla_tun tabla_ghe) do
      refute print(pass) =~ ~r/#{synth}, pass \d+.*\nbeat/, "pass #{pass} plays #{synth}"
    end
  end

  test "the gat plays page 33 matra by matra, the book's x on beat 1 and its 0 on beat 9" do
    expected =
      (@sthayi ++ @antara ++ @sthayi)
      |> List.flatten()
      |> Enum.with_index(8)
      |> Enum.flat_map(fn {cell, matra} ->
        notes = String.split(cell, "+")

        for {note, index} <- Enum.with_index(notes), note not in ["-", "_"] do
          {round_beat(matra + index / length(notes)), String.trim_leading(note, "~")}
        end
      end)

    # Each note is plucked or fingered on its matra; a grace note's pluck comes 0.12 beats before.
    played =
      for pass <- @gat,
          [beat, note] <-
            Regex.scan(~r/^beat ([\d.]+) +(?:play|control note:) ([\d.]+)/m, sitar(pass),
              capture: :all_but_first
            ),
          beat =
            round_beat(
              (pass - 9) * 16 + String.to_float(beat <> if(beat =~ ".", do: "", else: ".0"))
            ),
          round_beat(beat - floor(beat)) != 0.88 do
        {beat, name(note)}
      end

    differs = played |> Enum.zip(expected) |> Enum.find(fn {got, want} -> got != want end)

    assert played == expected,
           "#{length(played)} notes against #{length(expected)}, first differing #{inspect(differs)}"

    assert sitar(10) =~ ~r/^beat 2 +control note: 52.86, note_slide: 0.4$/m
  end

  test "the gat's tabla strikes sam on beat 1 and leaves the bayan out of the khali" do
    for pass <- @gat do
      printed = print(pass)
      assert printed =~ ~r/tabla_na, pass #{pass}.*?\nbeat 0 +play/s

      [ghe | _] = Regex.run(~r/tabla_ghe, pass .*?(\n\n|$)/s, printed)

      beats =
        Regex.scan(~r/^beat (\d+) +play/m, ghe, capture: :all_but_first)
        |> List.flatten()
        |> Enum.map(&String.to_integer/1)

      assert 0 in beats
      refute Enum.any?(beats, &(&1 in 8..11))
    end
  end

  test "every sitar note is one of Yaman's notes tuned against Sa in cents" do
    for pass <- @passes,
        [note] <-
          Regex.scan(~r/(?:play|control note:) ([\d.]+)/, sitar(pass), capture: :all_but_first) do
      assert name(note) != nil, "pass #{pass} plays #{note}"
    end
  end

  test "the song plays only the tanpura, the sitar and the tabla, and no samples" do
    for pass <- @passes do
      loops =
        Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) |> List.flatten()

      assert Enum.sort(loops) == ~w(chikari sitar tabla_ghe tabla_na tabla_tun tanpura)
      refute print(pass) =~ "sample "
    end
  end

  test "each sitar pluck rings until the next, and a grace note's pluck moves on to the note it ornaments" do
    for pass <- @passes,
        section = sitar(pass),
        plucks =
          Regex.scan(~r/^beat ([\d.]+) +play [\d.]+ vel: 0.6, sustain: ([\d.]+)/m, section,
            capture: :all_but_first
          ),
        [[beat, sustain], [next, _]] <- Enum.chunk_every(plucks, 2, 1, :discard) do
      assert_in_delta number(beat) + number(sustain),
                      number(next),
                      0.001,
                      "pass #{pass} beat #{beat}"
    end

    assert sitar(10) =~
             ~r/^beat 2.88 +play 56.02 .*\nbeat 3 +control note: 54.9, note_slide: 0.03\nbeat 3.333 +control note: 56.02, note_slide: 0$/m
  end

  test "the chikari strikes between the notes in the jor and on the gat's held matras, not in the alap" do
    refute print(0) =~ ~r/chikari, pass 0.*\nbeat/
    assert print(6) =~ ~r/chikari, pass 6.*\nbeat 0.5 +play 61 .*\nbeat 0.5 +play 73 /
    assert print(10) =~ ~r/chikari, pass 10.*\nbeat 1.5 +play 61 /
  end

  test "the README points to the song and names the book its gat comes from" do
    readme = File.read!("README.md")
    assert readme =~ "examples/raga.exs"
    assert readme =~ "Kramik Pustak Malika"
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

  defp sitar(pass) do
    pass |> print() |> String.split("\n\n") |> Enum.find(&String.starts_with?(&1, "sitar"))
  end

  defp number(text), do: String.to_float(if(text =~ ".", do: text, else: text <> ".0"))

  defp round_beat(beat), do: Float.round(beat * 1.0, 3)

  # A printed note as a swara of Yaman on Sa C#3, with a dot below or a quote above for the octaves, or nil when it is none.
  defp name(note) do
    cents = round((String.to_float(note) - 49) * 100)
    octave = Integer.floor_div(cents, 1200)
    swara = @steps[cents - octave * 1200]

    swara &&
      String.duplicate(".", max(-octave, 0)) <> swara <> String.duplicate("'", max(octave, 0))
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
