defmodule Mx.BandTest do
  # The tests hold mx's clock as a render does, which every process in the VM reads.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.{Band, Clock, OSC, Song}

  @beat_us 10_000

  setup ctx do
    test = self()
    played = %{play: fn at, events -> send(test, {:played, at, events}) end}

    # A test tagged realtime plays against the system's time, as a song played live does.
    if ctx[:realtime] do
      played
    else
      Clock.start_render(System.os_time(:microsecond))
      driver = spawn(fn -> drive([]) end)

      on_exit(fn ->
        Process.exit(driver, :kill)
        Clock.stop_render()
      end)

      Map.put(played, :driver, driver)
    end
  end

  @tag :tmp_dir
  test "sends each note stamped with its beat, pass after pass, without drifting", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(3, fn _, _ -> seq([note(60, 0), rest(1), note(64, 0), rest(1), note(67, 0), rest(1)]) end)))\n"
      )

    {_band, start_us} = start(song, ctx)

    notes = receive_notes(30)

    assert Enum.map(notes, &elem(&1, 1)) == List.flatten(List.duplicate([60.0, 64.0, 67.0], 10))
    assert Enum.map(notes, &elem(&1, 0)) == Enum.map(0..29, &(start_us + &1 * @beat_us))
  end

  @tag :tmp_dir
  test "fractional waits do not add up to a drift", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(0.1, fn _, _ -> seq([note(60, 0), rest(0.1)]) end)))\n"
      )

    {_band, start_us} = start(song, ctx)

    times = Enum.map(receive_notes(50), &elem(&1, 0))

    assert List.last(times) == start_us + 49 * div(@beat_us, 10)
  end

  @tag :tmp_dir
  test "sends the synth, note and play options to the engine", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:a, loop(1, fn _, _ -> seq([note(50, 0, amp: 0.5), rest(1)]) end), synth: :marimba))\n"
      )

    start(song, ctx)

    assert_receive {:played, _, [{:note, nil, :marimba, _, _, nil} = params]}
    assert %{note: 50.0, amp: 0.5} = params_map(params)
  end

  @tag :tmp_dir
  test "a strum sends each note at its own time, and sends no strum option", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, music: part(:a, loop(4, fn _, _ -> seq([note([60, 48, 55, 52], 0, strum: 0.05), rest(4)]) end), synth: :saw))\n"
      )

    start(song, ctx)

    sent =
      for _ <- 1..4 do
        assert_receive {:played, time, [{:note, nil, :saw, _, _, nil} = params]}
        {time, params_map(params)}
      end

    [first | _] = times = sent |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert Enum.map(times, &(&1 - first)) == [0, 25_000, 50_000, 75_000]

    by_time = sent |> Enum.sort() |> Enum.map(fn {_, params} -> params[:note] end)
    assert by_time == [48.0, 52.0, 55.0, 60.0]
    refute Enum.any?(sent, fn {_, params} -> Map.has_key?(params, "strum") end)
  end

  @tag :tmp_dir
  test "play with only options sends no note, so the synth plays its own", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:a, loop(1, fn _, _ -> seq([hit(amp: 0.5), rest(1)]) end), synth: :kick))\n"
      )

    start(song, ctx)

    assert_receive {:played, _, [{:note, nil, :kick, _, _, nil} = params]}
    assert params_map(params) == %{amp: 0.5}
  end

  @tag :tmp_dir
  test "time options are measured in beats, and sent in seconds at the tempo", ctx do
    assert first_params(ctx, 120, "release: 1")[:release] == 0.5
    assert first_params(ctx, 60, "release: 1")[:release] == 1.0
  end

  @tag :tmp_dir
  test "time options given per note are measured in beats, value by value", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note([45, 52], 0, release: [1, 2]), rest(1)]) end)))\n"
      )

    {band, _} = start(song, ctx)
    params = params_until(&(length(&1) >= 2))
    Process.unlink(band)
    GenServer.stop(band, :shutdown)

    releases =
      for {_time, params} <- params, map = params_map(params), do: {map[:note], map[:release]}

    assert Enum.take(releases, 2) == [{45.0, 0.5}, {52.0, 1.0}]
  end

  @tag :tmp_dir
  test "time options in a loop's defaults are measured in beats", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), defaults: [release: 2]))\n"
      )

    {band, _} = start(song, ctx)
    assert_receive {:played, _, [{:note, _, _, _, _, _} = params]}
    Process.unlink(band)
    GenServer.stop(band, :shutdown)
    assert params_map(params)[:release] == 1.0
  end

  @tag :tmp_dir
  test "changed defaults apply from the loop's next pass", ctx do
    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: part(:a, loop(2, fn _, _ -> seq([note(60, 0), rest(1), note(64, 0), rest(1)]) end), defaults: [amp: 0.5]))\n"
      )

    second =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: part(:a, loop(2, fn _, _ -> seq([note(60, 0), rest(1), note(64, 0), rest(1)]) end), defaults: [amp: 0.2]))\n"
      )

    {band, _} = start(first, ctx)
    params_until(&(length(&1) >= 2))
    Band.switch(band, second)

    played =
      params_until(fn played ->
        Enum.count(played, fn {_time, params} -> params_map(params)[:amp] == 0.2 end) >= 2
      end)

    Process.unlink(band)
    GenServer.stop(band, :shutdown)

    amps =
      for {_time, params} <- played,
          map = params_map(params),
          do: {map[:note], Float.round(map[:amp], 6)}

    {old, new} = Enum.split_while(amps, fn {_, amp} -> amp == 0.5 end)

    assert old
           |> Enum.map(&elem(&1, 0))
           |> Enum.chunk_every(2)
           |> Enum.all?(&(&1 == [60.0, 64.0]))

    assert [{60.0, 0.2}, {64.0, 0.2} | _] = new
    assert Enum.all?(new, fn {_, amp} -> amp == 0.2 end)
  end

  @tag :tmp_dir
  test "a synth's default time options are measured in beats too", ctx do
    assert first_params(ctx, 120, "amp: 1")[:release] == 0.5
  end

  @tag :tmp_dir
  test "attack, decay, sustain and slides are measured in beats", ctx do
    params = first_params(ctx, 120, "attack: 2, sustain: 1, decay: 0.5, note_slide: 1")

    assert {params[:attack], params[:sustain], params[:decay], params[:note_slide]} ==
             {1.0, 0.5, 0.25, 0.5}
  end

  @tag :tmp_dir
  test "tremolo is measured in picks per beat, and sent in picks per second at the tempo", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note(69, 0, tremolo: 8), rest(1)]) end), synth: :bandolim))\n"
      )

    start(song, ctx)

    assert_receive {:played, _, [{:note, nil, :bandolim, _, _, nil} = params]}
    assert params_map(params)[:tremolo] == 16.0
  end

  @tag :tmp_dir
  test "motor is measured in pulses per beat, and sent in pulses per second at the tempo", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0, motor: 2), rest(1)]) end), synth: :vibraphone))\n"
      )

    start(song, ctx)

    assert_receive {:played, _, [{:note, nil, :vibraphone, _, _, nil} = params]}
    assert params_map(params)[:motor] == 4.0
  end

  @tag :tmp_dir
  test "options that are not times are sent unchanged", ctx do
    params = first_params(ctx, 120, "amp: 0.5, pan: -1, sustain_level: 0.8")
    assert {params[:amp], params[:pan], params[:sustain_level]} == {0.5, -1.0, 0.8}
  end

  @tag :tmp_dir
  test "notes after a tempo change use the new length of a beat", ctx do
    part = "part(:a, loop(1, fn _, _ -> seq([note(60, 0, release: 1), rest(1)]) end))"
    first = load(ctx, song(6000, [part]))
    second = load(ctx, song(3000, [part]))

    {band, _} = start(first, ctx)
    before = releases_until(&(&1 != []))
    Band.switch(band, second)
    releases = before ++ releases_until(&(0.02 in &1))

    assert hd(releases) == 0.01
    assert List.last(releases) == 0.02
    assert Enum.uniq(releases) == [0.01, 0.02]
  end

  @tag :tmp_dir
  test "loops of different lengths start on the same beat and line up where their lengths meet",
       ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: together([part(:drums, loop(4, fn _, _ -> seq([note(36, 0), rest(4)]) end)), part(:melody, loop(3, fn _, _ -> seq([note(60, 0), rest(1), note(62, 0), rest(2)]) end))]))\n"
      )

    {_band, start_us} = start(song, ctx)
    notes = collect_until(counted(%{36 => 6, 60 => 8}))

    assert Enum.take(times(notes, 36), 6) == Enum.map(0..5, &(start_us + &1 * 4 * @beat_us))
    assert Enum.take(times(notes, 60), 8) == Enum.map(0..7, &(start_us + &1 * 3 * @beat_us))
    assert (start_us + 12 * @beat_us) in times(notes, 36)
    assert (start_us + 12 * @beat_us) in times(notes, 60)
  end

  @tag :tmp_dir
  test "a song played from a beat starts each loop in the pass that holds it, from that beat",
       ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: together([part(:drums, loop(4, fn pass, _ -> seq([note(36 + pass, 0), rest(4)]) end)), part(:melody, loop(3, fn pass, _ -> seq([note(60 + pass, 0), rest(1), note(70 + pass, 0), rest(2)]) end))]))\n"
      )

    {_band, start_us} = start(song, ctx, from: 7)
    notes = collect_until(counted(%{38 => 1, 72 => 1, 63 => 1, 73 => 1}))

    assert times(notes, 38) == [start_us + 1 * @beat_us]
    assert times(notes, 72) == [start_us]
    assert times(notes, 63) == [start_us + 2 * @beat_us]
    assert times(notes, 73) == [start_us + 3 * @beat_us]
    assert times(notes, 37) ++ times(notes, 61) ++ times(notes, 62) == []
  end

  @tag :tmp_dir
  test "a removed loop stops at the end of its current pass, and the others play on", ctx do
    drums = "part(:drums, loop(4, fn _, _ -> seq([note(36, 0), rest(4)]) end))"

    bass =
      "part(:bass, loop(4, fn _, _ -> seq(for pitch <- 40..43, do: seq([note(pitch, 0), rest(1)])) end))"

    first = load(ctx, song(600, [drums, bass]))
    second = load(ctx, song(600, [drums]))

    {band, start_us} = start(first, ctx)
    before = collect_through(41.0)
    Band.switch(band, second)

    notes =
      collect_until(
        fn notes ->
          last_bass = List.last(times(notes, 43))
          last_bass && List.last(times(notes, 36)) > last_bass + 400_000
        end,
        before
      )

    bass_notes = for {time, note} <- notes, note in [40.0, 41.0, 42.0, 43.0], do: {time, note}
    assert {_, 43.0} = List.last(bass_notes)
    assert rem(length(bass_notes), 4) == 0
    {last_bass, _} = List.last(bass_notes)

    drum_times = times(notes, 36)
    assert List.last(drum_times) > last_bass + 400_000
    assert drum_times == Enum.map(0..(length(drum_times) - 1), &(start_us + &1 * 400_000))
  end

  @tag :tmp_dir
  test "a loop added back while it finishes its pass takes over at the end of that pass", ctx do
    drums = "part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end))"

    bass =
      "part(:bass, loop(4, fn _, _ -> seq(for pitch <- 40..43, do: seq([note(pitch, 0), rest(1)])) end))"

    back = String.replace(bass, "40..43", "50..53")
    first = load(ctx, song(600, [drums, bass]))
    removed = load(ctx, song(600, [drums]))
    added = load(ctx, song(600, [drums, back]))

    {band, start_us} = start(first, ctx)
    before = collect_through(41.0)
    Band.switch(band, removed)
    Band.switch(band, added)
    notes = collect_until(counted(%{53 => 1}), before)

    bass_notes = for {time, note} <- notes, note != 36.0, do: {time, round(note)}
    bass_times = Enum.map(bass_notes, &elem(&1, 0))
    assert bass_times == Enum.map(0..(length(bass_times) - 1), &(start_us + &1 * 100_000))

    {old, new} = Enum.split_while(bass_notes, fn {_, note} -> note < 50 end)

    assert old
           |> Enum.map(&elem(&1, 1))
           |> Enum.chunk_every(4)
           |> Enum.all?(&(&1 == [40, 41, 42, 43]))

    assert [{switch_us, 50}, {_, 51}, {_, 52}, {_, 53} | _] = new
    assert rem(switch_us - start_us, 400_000) == 0
  end

  @tag :tmp_dir
  test "a loop added back after its removed version stopped starts on the next beat", ctx do
    drums = "part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end))"

    bass =
      "part(:bass, loop(4, fn _, _ -> seq(for pitch <- 40..43, do: seq([note(pitch, 0), rest(1)])) end))"

    first = load(ctx, song(600, [drums, bass]))
    removed = load(ctx, song(600, [drums]))

    {band, start_us} = start(first, ctx)
    collect_through(41.0)
    Band.switch(band, removed)

    collect_until(fn notes ->
      last_bass = List.last(times(notes, 43))
      last_bass && List.last(times(notes, 36)) >= last_bass + 200_000
    end)

    switch_us = Clock.now()
    Band.switch(band, load(ctx, song(600, [drums, bass])))
    notes = collect_until(counted(%{43 => 1}))

    [first_bass | _] = times(notes, 40)
    assert first_bass > switch_us
    assert first_bass - switch_us < 20_000 + 2 * 100_000 + 10_000
    assert rem(first_bass - start_us, 100_000) == 0
    bass_times = for {time, note} <- notes, note in [40.0, 41.0, 42.0, 43.0], do: time
    assert bass_times == Enum.uniq(bass_times)
  end

  @tag :tmp_dir
  test "a tempo change applies to every loop on the same beat", ctx do
    drums = "part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end))"
    hats = "part(:hats, loop(0.5, fn _, _ -> seq([note(42, 0), rest(0.5)]) end))"
    first = load(ctx, song(6000, [drums, hats]))
    second = load(ctx, song(3000, [drums, hats]))

    {band, start_us} = start(first, ctx)
    before = collect_until(counted(%{36 => 3}))
    Band.switch(band, second)

    notes =
      collect_until(
        fn notes ->
          tempo_change(times(notes, 36), @beat_us, 2 * @beat_us) &&
            tempo_change(times(notes, 42), div(@beat_us, 2), @beat_us)
        end,
        before
      )

    drums_change = tempo_change(times(notes, 36), @beat_us, 2 * @beat_us)
    hats_change = tempo_change(times(notes, 42), div(@beat_us, 2), @beat_us)

    assert drums_change == hats_change
    assert rem(drums_change - start_us, @beat_us) == 0
  end

  @tag :tmp_dir
  test "a loop that fails while playing restarts from its next pass, and the others play on",
       ctx do
    song =
      load(ctx, """
      import Mx

      song(
        tempo: 6000,
        music:
          together([
            part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end)),
            part(:flaky, loop(1, fn pass, _ -> if(pass == 2, do: raise("boom"), else: seq([note(60, 0), rest(1)])) end))
          ])
      )
      """)

    output =
      capture_io(:stderr, fn ->
        {_band, start_us} = start(song, ctx)
        notes = collect_until(counted(%{36 => 6, 60 => 4}))
        send(self(), {:result, start_us, notes})
      end)

    assert_received {:result, start_us, notes}
    drum_times = times(notes, 36)
    assert drum_times == Enum.map(0..(length(drum_times) - 1), &(start_us + &1 * @beat_us))

    assert [first, second, third, fourth | _] = times(notes, 60)
    assert [first, second] == [start_us, start_us + @beat_us]
    assert [third, fourth] == [start_us + 3 * @beat_us, start_us + 4 * @beat_us]

    assert output =~ "part flaky"
    assert output =~ "boom"
  end

  @tag :tmp_dir
  test "a loop whose process dies starts again on a later beat, and the others play on", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: together([part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end)), part(:melody, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end))]))\n"
      )

    output =
      capture_io(:stderr, fn ->
        {band, start_us} = start(song, ctx)
        before = collect_until(counted(%{60 => 1}))
        Process.exit(:sys.get_state(band).loops.melody, :kill)
        notes = collect_until(counted(%{60 => length(times(before, 60)) + 5}), before)
        send(self(), {:result, start_us, notes})
      end)

    assert_received {:result, start_us, notes}
    drum_times = times(notes, 36)
    assert drum_times == Enum.map(0..(length(drum_times) - 1), &(start_us + &1 * @beat_us))
    assert List.last(times(notes, 60)) > List.last(drum_times) - 3 * @beat_us
    assert Enum.all?(times(notes, 60), &(rem(&1 - start_us, @beat_us) == 0))
    assert output =~ "loop melody failed and starts again"
  end

  describe "tempo changes written in the music" do
    @describetag :tmp_dir

    test "a rise plays each beat shorter than the one before, then holds the new tempo", ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 6000, music: part(:a, seq([tempo(7800, over: 16), repeat(seq([note(60, 0), rest(1)]), 24)])))
        """)

      {_band, start_us} = start(song, ctx)
      times = times(collect_until(counted(%{60 => 23})), 60)
      gaps = Enum.zip_with(times, tl(times), &(&2 - &1))

      assert hd(times) == start_us
      assert_in_delta hd(gaps), 60_000_000 / 6000, 300
      rising = Enum.take(gaps, 16)
      assert rising == Enum.sort(rising, :desc) and rising == Enum.uniq(rising)

      for gap <- gaps |> Enum.drop(16) |> Enum.take(6) do
        assert_in_delta gap, 60_000_000 / 7800, 2
      end
    end

    test "a section after a sudden change plays at the new tempo from its first beat", ctx do
      song =
        load(ctx, """
        import Mx

        song(
          tempo: 6000,
          music:
            seq([
              part(:a, repeat(seq([note(60, 0), rest(1)]), 4)),
              tempo(8400),
              part(:a, repeat(seq([note(62, 0), rest(1)]), 4))
            ])
        )
        """)

      {_band, start_us} = start(song, ctx)
      notes = collect_until(counted(%{60 => 4, 62 => 4}))

      assert times(notes, 60) == Enum.map(0..3, &(start_us + &1 * @beat_us))
      assert [first | _] = second = times(notes, 62)
      assert first == start_us + 4 * @beat_us

      for gap <- Enum.zip_with(second, tl(second), &(&2 - &1)) do
        assert_in_delta gap, 60_000_000 / 8400, 2
      end
    end

    test "loops of different lengths still start their passes together through a change", ctx do
      song =
        load(ctx, """
        import Mx

        song(
          tempo: 6000,
          music:
            seq([
              tempo(9000, over: 12),
              together([
                part(:drums, loop(1, fn _, _ -> seq([note(36, 0), rest(1)]) end)),
                part(:melody, loop(3, fn _, _ -> seq([note(60, 0), rest(3)]) end))
              ])
            ])
        )
        """)

      start(song, ctx)
      notes = collect_until(counted(%{36 => 16, 60 => 6}))
      drums = times(notes, 36)
      melody = Enum.take(times(notes, 60), 6)

      assert length(melody) == 6
      for time <- melody, do: assert(time in drums)
      assert Enum.at(melody, 1) == Enum.at(drums, 3)
    end

    test "a note's release in beats lasts a beat at the tempo when the note starts", ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 6000, music: part(:a, seq([tempo(12000, over: 8), repeat(seq([note(60, 0, release: 1), rest(1)]), 10)])))
        """)

      start(song, ctx)
      releases = releases_until(&(length(&1) >= 10))

      assert length(releases) == 10

      for {release, beat} <- Enum.with_index(releases) do
        bpm = 6000 + 6000 * min(beat, 8) / 8
        assert_in_delta release, 60 / bpm, 1.0e-6
      end
    end

    test "plays the same notes at the same times on every run", ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 6000, music: part(:a, seq([rest(2), tempo(9000, over: 8), repeat(seq([note(60, 0), rest(0.5)]), 24)])))
        """)

      runs =
        for _ <- 1..2 do
          {band, start_us} = start(song, ctx)
          notes = collect_until(counted(%{60 => 24}))
          GenServer.stop(band)
          for {time, note} <- notes, do: {time - start_us, note}
        end

      assert length(hd(runs)) == 24
      assert Enum.at(runs, 0) == Enum.at(runs, 1)
    end

    test "a saved version whose song tempo is the same keeps the tempo its music changed to",
         ctx do
      body = fn note ->
        """
        import Mx
        song(tempo: 6000, music: repeat(seq([part(:a, seq([tempo(3000), note(#{note}, 0), rest(1)]))])))
        """
      end

      {band, start_us} = start(load(ctx, body.(60)), ctx)
      before = collect_until(counted(%{60 => 1}))
      Band.switch(band, load(ctx, body.(62)))
      notes = collect_until(counted(%{62 => 2}), before)

      assert hd(times(notes, 60)) == start_us

      all = Enum.map(notes, &elem(&1, 0))
      assert Enum.any?(notes, &(round(elem(&1, 1)) == 62))
      assert Enum.zip_with(all, tl(all), &(&2 - &1)) |> Enum.uniq() == [2 * @beat_us]
    end
  end

  describe "given hand, passes handed over whole in beats" do
    @describetag :tmp_dir

    setup do
      test = self()

      %{
        hand_opts: [
          hand: fn name, span, label, events, opts ->
            send(test, {:handed, name, span, label, events, opts})
          end,
          place_beats: fn start_us -> send(test, {:beats_placed, start_us}) end,
          set_tempo: fn beat, tempo -> send(test, {:tempo_set, beat, tempo}) end
        ]
      }
    end

    @tag :realtime
    test "a loop hands each pass with its beats, its number and every sound at its beat, with times left in beats",
         ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 6000, music: part(:a, loop(4, fn _, _ -> seq([note(60, 1, release: 2), note(64, 1.5), rest(1.5)]) end), synth: :saw))
        """)

      {_band, start_us} = start(song, ctx, ctx.hand_opts)

      assert_receive {:beats_placed, ^start_us}
      assert_receive {:tempo_set, 0, 6000}
      assert_receive {:handed, :a, {first_from, first_to}, 0, events, notice: 2}
      assert {first_from, first_to} == {0, 4}
      assert [{first, {:note, _, :saw, _, _, _} = low}, {second, high}] = events
      assert {first, second} == {0, 1}
      assert %{note: 60.0, sustain: 1.0, release: 2.0} = params_map(low)
      assert %{note: 64.0, sustain: 1.5} = params_map(high)
      assert_receive {:handed, :a, {second_from, second_to}, 1, _events, notice: 2}
      assert {second_from, second_to} == {4, 8}
      refute_received {:played, _, _}
    end

    test "works out the next pass as soon as it is told the pass ends, however far ahead that is",
         ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 60, music: part(:a, loop(8, fn _, _ -> seq([note(60, 1), rest(7)]) end)))
        """)

      {band, _start_us} = start(song, ctx, ctx.hand_opts)
      assert_receive {:handed, :a, _span, 0, _events, _opts}
      refute_receive {:handed, _, _, _, _, _}
      [loop] = Band.loops(band)

      send(loop, {:mx_pass_ending, :a, 4.0})
      refute_receive {:handed, _, _, _, _, _}
      send(loop, {:mx_pass_ending, :a, 8.0})
      assert_receive {:handed, :a, {from, to}, 1, [{at, _note}], _opts}
      assert {from, to, at} == {8, 16, 8}
    end

    test "the next pass reads the inputs as they are when the engine says the pass ends, and a later value waits a pass",
         ctx do
      {:ok, agent} = Agent.start_link(fn -> %{} end)

      song =
        load(ctx, """
        import Mx
        song(tempo: 60, music: part(:a, loop(4, fn _, inputs -> seq([note(inputs.cc[74] || 1, 1), rest(3)]) end)))
        """)

      opts = ctx.hand_opts ++ [inputs: fn _beat, _until_us -> Agent.get(agent, & &1) end]
      {band, _start_us} = start(song, ctx, opts)
      assert_receive {:handed, :a, _span, 0, [{0, first}], _opts}
      assert %{note: 1.0} = params_map(first)
      [loop] = Band.loops(band)

      Agent.update(agent, &Map.put(&1, {:cc, 74}, 64))
      send(loop, {:mx_pass_ending, :a, 4.0})
      assert_receive {:handed, :a, _span, 1, [{4, second}], _opts}
      Agent.update(agent, &Map.put(&1, {:cc, 74}, 100))

      assert %{note: 64.0} = params_map(second)
      send(loop, {:mx_pass_ending, :a, 8.0})
      assert_receive {:handed, :a, _span, 2, [{8, third}], _opts}
      assert %{note: 100.0} = params_map(third)
    end

    test "a change saved in the middle of a pass is handed over with the next pass", ctx do
      first =
        load(ctx, song(60, ["part(:a, loop(4, fn _, _ -> seq([note(60, 1), rest(3)]) end))"]))

      second =
        load(ctx, song(60, ["part(:a, loop(4, fn _, _ -> seq([note(67, 1), rest(3)]) end))"]))

      {band, _start_us} = start(first, ctx, ctx.hand_opts)
      assert_receive {:handed, :a, _span, 0, [{0, _note}], _opts}
      [loop] = Band.loops(band)
      Band.switch(band, second)
      refute_receive {:handed, _, _, _, _, _}

      send(loop, {:mx_pass_ending, :a, 4.0})
      assert_receive {:handed, :a, _span, 1, [{4, changed}], _opts}
      assert %{note: 67.0} = params_map(changed)
    end

    test "a saved version with a new tempo starts it on the first whole beat more than 150 ms away",
         ctx do
      part = "part(:a, loop(4, fn _, _ -> seq([rest(4)]) end))"
      first = load(ctx, song(120, [part]))
      second = load(ctx, song(90, [part]))
      at_beat_10_2 = Clock.now() - 5_100_000

      capture_io(:stderr, fn ->
        {band, _} = start(first, ctx, ctx.hand_opts ++ [start_us: at_beat_10_2, ahead_ms: 500])
        assert_receive {:tempo_set, 0, 120}
        Band.switch(band, second)

        assert_receive {:tempo_set, 11, 90}
        assert [{11, _, 90}, {0, ^at_beat_10_2, 120}] = Band.timeline(band)
        stop_quietly(band)
      end)
    end

    test "without hand, a saved tempo waits for the notes already sent", ctx do
      part = "part(:a, loop(4, fn _, _ -> seq([rest(4)]) end))"
      first = load(ctx, song(120, [part]))
      second = load(ctx, song(90, [part]))
      at_beat_10_2 = Clock.now() - 5_100_000

      capture_io(:stderr, fn ->
        {band, _} = start(first, ctx, start_us: at_beat_10_2, ahead_ms: 500)
        Band.switch(band, second)

        assert [{12, _, 90}, {0, ^at_beat_10_2, 120}] = Band.timeline(band)
        stop_quietly(band)
      end)
    end

    test "tells set_tempo each change the music writes, at its beat, and leaves the effects in beats",
         ctx do
      test = self()

      start_part = fn name, chain ->
        send(test, {:part_started, name, chain})
        %{part: name}
      end

      song =
        load(ctx, """
        import Mx
        song(tempo: 6000, music: part(:a, seq([tempo(7800, over: 16), repeat(seq([note(60, 0), rest(1)]), 24)]), fx: [echo: [phase: 0.5]]))
        """)

      start(song, ctx, ctx.hand_opts ++ [start_part: start_part])

      assert_receive {:tempo_set, 0, 6000}
      assert_receive {:tempo_set, 0, {:ramp, 6000, 7800, 16}}
      assert_receive {:part_started, :a, [echo: [phase: 0.5]]}
      assert_receive {:handed, :a, _span, 0, _events, _opts}
      refute_received {:part_started, _, _}
      refute_received {:tempo_set, _, _}
    end
  end

  describe "a tempo share" do
    @describetag :tmp_dir

    setup do
      test = self()

      %{
        tempo_opts: [
          hand: fn _name, _span, _label, _events, _opts -> :ok end,
          set_tempo: fn beat, tempo -> send(test, {:tempo_set, beat, tempo}) end
        ]
      }
    end

    test "plays the song at the share from 150 ms on, and 1 brings back the song's own tempo",
         ctx do
      {band, _start_us} = start(load(ctx, song(120, [click()])), ctx, ctx.tempo_opts)
      assert_receive {:tempo_set, 0, 120}

      asked_us = Clock.now()
      assert Band.scale_tempo(band, 0.5) == :ok
      assert [{beat, at_us, 60.0} | _] = Band.timeline(band)
      assert_received {:tempo_set, ^beat, 60.0}
      assert (at_us - asked_us) in 150_000..200_000
      assert_in_delta Band.time_at(Band.timeline(band), beat + 1) - at_us, 1_000_000, 1

      assert Band.scale_tempo(band, 1) == :ok
      assert [{_beat, _us, 120.0} | _] = Band.timeline(band)
    end

    test "scales the tempo changes the music writes, those already on the timeline too", ctx do
      music =
        "part(:a, seq([repeat(seq([note(60, 0), rest(1)]), 16), tempo(90), repeat(seq([note(60, 0), rest(1)]), 16)]))"

      {band, _start_us} =
        start(load(ctx, song(120, [music])), ctx, ctx.tempo_opts ++ [share: 0.5])

      assert_receive {:tempo_set, 0, 60.0}
      assert_receive {:tempo_set, 16, 45.0}

      assert Band.scale_tempo(band, 2) == :ok
      assert_receive {:tempo_set, 16, 180.0}
      assert [{16, _, 180.0}, {_beat, _, 240.0} | _] = Band.timeline(band)
    end

    test "a share kept through a saved version, which plays its own tempo at the share", ctx do
      first = load(ctx, song(120, [click()]))
      changed = load(ctx, song(120, [click(67)]))
      faster = load(ctx, song(100, [click(67)]))

      {band, _start_us} = start(first, ctx, ctx.tempo_opts)
      :ok = Band.scale_tempo(band, 0.5)
      Band.switch(band, changed)
      assert [{_beat, _us, 60.0} | _] = Band.timeline(band)
      Band.switch(band, faster)
      assert [{_beat, _us, 50.0} | _] = Band.timeline(band)
    end

    test "a share given over beats makes each of those beats longer than the one before", ctx do
      {band, _start_us} = start(load(ctx, song(120, [click()])), ctx, ctx.tempo_opts)
      :ok = Band.scale_tempo(band, 0.5, 4)

      assert [{ended, _, 60.0}, {beat, _, {:ramp, 120, 60.0, 4}} | _] =
               timeline = Band.timeline(band)

      assert ended == beat + 4

      lengths =
        for at <- 0..3,
            do: Band.time_at(timeline, beat + at + 1) - Band.time_at(timeline, beat + at)

      assert lengths == Enum.sort(lengths) and lengths == Enum.uniq(lengths)
    end

    test "a share outside 0.25 to 4 is refused, naming the limits", ctx do
      {band, _start_us} = start(load(ctx, song(120, [click()])), ctx, ctx.tempo_opts)

      assert Band.scale_tempo(band, 5) == {:error, "a tempo share takes 0.25 to 4, not 5"}
      assert Band.scale_tempo(band, 0.2) == {:error, "a tempo share takes 0.25 to 4, not 0.2"}
      assert [{0, _, 120}] = Band.timeline(band)
    end
  end

  describe "samples" do
    @describetag :tmp_dir

    test "a sample plays as the song loaded it, with its options and no note", ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 120, music: part(:drums, loop(1, fn _, _ -> seq([sample({:sonic_pi, :bd_haus}, 0, rate: 2, release: 1, sustain: 0), sample(\"test/support/samples/sn_dolf.flac\", 0), rest(1)]) end)))\n"
        )

      bd_haus = Path.expand("test/support/samples/bd_haus.flac")
      sn_dolf = Path.expand("test/support/samples/sn_dolf.flac")
      buffers = %{bd_haus => %{buf: 7, channels: 2}, sn_dolf => %{buf: 8, channels: 1}}
      start(song, ctx, prepare: &prepared(&1, buffers))

      assert_receive {:played, _, [{:sample, nil, %{buf: 7}, _, nil} = params]}
      assert %{rate: 2.0, release: 0.5, sustain: +0.0} = params_map(params)
      refute Map.has_key?(params_map(params), :note)

      assert_receive {:played, _, [{:sample, nil, %{buf: 8}, _, nil} = params]}
      refute Map.has_key?(params_map(params), :sustain)
    end

    @tag :realtime
    test "samples are ready before playing starts, so the first pass is on time", ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 6000, music: part(:drums, loop(1, fn _, _ -> seq([sample({:sonic_pi, :bd_haus}, 0), rest(1)]) end)))\n"
        )

      bd_haus = Path.expand("test/support/samples/bd_haus.flac")

      slow = fn song ->
        Process.sleep(100)
        prepared(song, %{bd_haus => %{buf: 1, channels: 2}})
      end

      output =
        capture_io(:stderr, fn ->
          {:ok, band} = Band.start_link(song: song, play: ctx.play, ahead_ms: 20, prepare: slow)
          driven(band, ctx)
          assert_receive {:played, time, _}
          assert time > Clock.now()
        end)

      refute output =~ "late"
    end

    test "a sample named while the pass runs is loaded, and plays from the next pass", ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 6000, music: part(:drums, loop(1, fn _, _ -> seq([sample({:sonic_pi, String.to_atom(\"bd_\" <> \"haus\")}, 0), rest(1)]) end)))\n"
        )

      test = self()
      load_sample = fn path, loop -> send(test, {:load_sample, path, loop}) end

      output =
        capture_io(:stderr, fn ->
          start(song, ctx, load_sample: load_sample)
          assert_receive {:load_sample, path, loop}
          refute_receive {:played, _, _}
          send(loop, {:sample_loaded, path, %{buf: 4, channels: 2}})
          assert_receive {:played, _, [{:sample, _, %{buf: 4}, _, _}]}
        end)

      assert output =~ "loop drums loads sample bd_haus, which plays from its next pass"
    end
  end

  describe "effects" do
    setup do
      test = self()

      start_fx = fn chain ->
        number = System.unique_integer([:positive])
        send(test, {:fx_started, number, chain})
        %{group: 1000 + number, bus: 64 + 2 * number}
      end

      stop_fx = fn fx, at_us -> send(test, {:fx_stopped, fx, at_us}) end
      %{fx_opts: [start_fx: start_fx, stop_fx: stop_fx]}
    end

    @tag :tmp_dir
    test "a loop with effects plays into its chain, which lasts from pass to pass, and a loop without plays dry",
         ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 6000, music: together([part(:wet, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: :reverb), part(:dry, loop(1, fn _, _ -> seq([note(62, 0), rest(1)]) end))]))\n"
        )

      start(song, ctx, ctx.fx_opts)
      assert_receive {:fx_started, number, [{:reverb, _}]}
      notes = targets_until(&(length(&1) > 20))

      assert length(notes) > 20

      assert notes
             |> Enum.filter(&(&1.note == 60.0))
             |> Enum.map(& &1.chain)
             |> Enum.uniq() == [%{group: 1000 + number, bus: 64 + 2 * number}]

      assert notes
             |> Enum.filter(&(&1.note == 62.0))
             |> Enum.map(& &1.chain)
             |> Enum.uniq() == [nil]

      refute_received {:fx_started, _, _}
    end

    @tag :tmp_dir
    test "given start_part, every loop plays into a part started by its name with its effects",
         ctx do
      test = self()

      start_part = fn name, chain ->
        send(test, {:part_started, name, chain})
        %{part: name}
      end

      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 6000, music: together([part(:wet, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: :reverb), part(:dry, loop(1, fn _, _ -> seq([note(62, 0), rest(1)]) end))]))\n"
        )

      start(song, ctx, ctx.fx_opts ++ [start_part: start_part])
      assert_receive {:part_started, :wet, [{:reverb, _}]}
      assert_receive {:part_started, :dry, []}

      notes =
        targets_until(
          &(Enum.any?(&1, fn t -> t.note == 60.0 end) and
              Enum.any?(&1, fn t -> t.note == 62.0 end))
        )

      assert notes |> Enum.map(&{&1.note, &1.chain}) |> Enum.uniq() |> Enum.sort() ==
               [{60.0, %{part: :wet}}, {62.0, %{part: :dry}}]

      refute_received {:part_started, _, _}
      refute_received {:fx_started, _, _}
    end

    @tag :tmp_dir
    test "mutes and solos the song's parts by name through its functions, and refuses a part the song does not have",
         ctx do
      test = self()

      opts = [
        mute: fn name, muted -> send(test, {:mute, name, muted}) end,
        solo: fn name, soloed -> send(test, {:solo, name, soloed}) end
      ]

      content =
        "import Mx\nsong(tempo: 6000, music: together([part(:bass, loop(1, fn _, _ -> seq([note(40, 0), rest(1)]) end)), part(:lead, loop(1, fn _, _ -> seq([note(72, 0), rest(1)]) end)), part(:keys, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end))]))\n"

      {band, _} = start(load(ctx, content), ctx, opts)

      assert Band.mute(band, :lead) == :ok
      assert_received {:mute, :lead, true}
      assert Band.mute(band, "lead", false) == :ok
      assert_received {:mute, :lead, false}

      assert Band.mute(band, :no_such_part) == {:error, "the song has no part named no_such_part"}
      assert Band.solo(band, [:bass, "nope"]) == {:error, "the song has no part named nope"}
      refute_received {:mute, _, _}
      refute_received {:solo, _, _}

      assert Band.solo(band, [:bass, :keys]) == :ok
      assert_received {:solo, :bass, true}
      assert_received {:solo, :keys, true}
      assert Band.solo(band, ["keys", :lead]) == :ok
      assert_received {:solo, :bass, false}
      assert_received {:solo, :lead, true}
      refute_received {:solo, :keys, _}

      Band.switch(band, load(ctx, String.replace(content, "6000", "3000")))
      assert Band.solo(band, []) == :ok
      assert_received {:solo, :keys, false}
      assert_received {:solo, :lead, false}
      refute_received {:solo, _, _}
    end

    @tag :tmp_dir
    test "a part of a song written as music that another changes plays in a group of its own, which the change sets",
         ctx do
      song =
        load(ctx, """
        import Mx
        song(tempo: 600, music: repeat(together([
          part(:pads, note(:c4, 2), synth: :saw),
          part(:conductor, seq([rest(1), change(:pads, cutoff: 80), rest(1)]))
        ])))
        """)

      {_band, start_us} = start(song, ctx, ctx.fx_opts)
      assert_receive {:fx_started, number, []}

      messages =
        messages_until(fn messages ->
          Enum.any?(messages, &match?({_, {:note, _, :saw, _, _, _}}, &1)) and
            Enum.any?(messages, &match?({_, {:set, _, _}}, &1))
        end)

      started = for {time, {:note, _, :saw, _, _, chain}} <- messages, do: {time, chain}
      assert [{^start_us, %{group: group} = chain} | _] = started
      assert group == 1000 + number

      set = for {time, {:set, target, params}} <- messages, do: {time, target, params}
      assert [{time, {:part, ^chain}, [cutoff: 80]} | _] = set
      assert time == start_us + 100_000
    end

    @tag :tmp_dir
    test "effects chain in the order listed, with their time options in seconds at the tempo",
         ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: [echo: [phase: 1], reverb: [decay_seconds: 3.2]]))\n"
        )

      start(song, ctx, ctx.fx_opts)

      assert_receive {:fx_started, _, [{:echo, echo}, {:reverb, reverb}]}
      assert echo[:phase] == 0.5
      assert echo[:decay] == 1.0
      assert reverb[:decay_seconds] == 3.2
    end

    @tag :tmp_dir
    test "a flanger and a reverb chain in the order listed, the flanger's decay in seconds at the tempo",
         ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 120, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: [flanger: [], reverb: [decay_seconds: 3.2]]))\n"
        )

      start(song, ctx, ctx.fx_opts)

      assert_receive {:fx_started, _, [{:flanger, flanger}, {:reverb, reverb}]}
      assert flanger[:phase] == 2.0
      assert flanger[:decay] == 1.0
      assert flanger[:delay] == nil
      assert reverb[:decay_seconds] == 3.2
    end

    @tag :tmp_dir
    test "changed effects take over at the end of the pass, and the old chain stops there", ctx do
      first =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: :reverb))\n"
        )

      second =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: :echo))\n"
        )

      {band, _} = start(first, ctx, ctx.fx_opts)
      assert_receive {:fx_started, old_n, [{:reverb, _}]}
      before = targets_until(&(&1 != []))
      Band.switch(band, second)

      assert_receive {:fx_started, new_n, [{:echo, _}]}
      assert_receive {:fx_stopped, %{group: old_group}, at_us}
      assert old_group == 1000 + old_n
      notes = targets_until(&Enum.any?(&1, fn target -> target.time >= at_us end), before)

      {old, new} = Enum.split_with(notes, &(&1.time < at_us))
      assert Enum.all?(old, &(&1.chain.group == 1000 + old_n))
      assert [%{time: ^at_us} | _] = new
      assert Enum.all?(new, &(&1.chain.group == 1000 + new_n))
    end

    @tag :tmp_dir
    test "a version with the same effects keeps the chain", ctx do
      first =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: :reverb))\n"
        )

      second =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, _ -> seq([note(62, 0), rest(1)]) end), fx: :reverb))\n"
        )

      {band, _} = start(first, ctx, ctx.fx_opts)
      assert_receive {:fx_started, _, _}
      Band.switch(band, second)

      targets_until(&Enum.any?(&1, fn target -> target.note == 62.0 end))
      refute_received {:fx_started, _, _}
      refute_received {:fx_stopped, _, _}
    end

    @tag :tmp_dir
    test "a removed loop stops its chain at the end of its last pass", ctx do
      wet =
        "part(:wet, loop(2, fn _, _ -> seq([note(60, 0), rest(1), note(61, 0), rest(1)]) end), fx: :reverb)"

      dry =
        "part(:dry, loop(2, fn _, _ -> seq([note(62, 0), rest(1), note(62, 0), rest(1)]) end))"

      first = load(ctx, song(600, [wet, dry]))
      second = load(ctx, song(600, [dry]))

      {band, _} = start(first, ctx, ctx.fx_opts)
      assert_receive {:fx_started, number, _}
      before = targets_until(&(&1 != []))
      Band.switch(band, second)

      assert_receive {:fx_stopped, %{group: group}, at_us}
      assert group == 1000 + number
      notes = targets_until(&Enum.any?(&1, fn target -> target.time >= at_us end), before)
      last_wet = notes |> Enum.filter(&(&1.chain[:group] == group)) |> List.last()

      assert last_wet.note == 61.0
      assert at_us == last_wet.time + 100_000
    end
  end

  @tag :tmp_dir
  test "hands the live audio of each version to live, with the tempo", ctx do
    test = self()

    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, live_audio: [mic: []], music: part(:a, loop(1, fn _, _ -> rest(1) end)))\n"
      )

    second =
      load(
        ctx,
        "import Mx\nsong(tempo: 120, live_audio: [mic: [amp: 0.5]], music: part(:a, loop(1, fn _, _ -> rest(1) end)))\n"
      )

    {band, _} = start(first, ctx, live: fn lives, tempo -> send(test, {:live, lives, tempo}) end)
    assert_receive {:live, [%{name: :mic, opts: []}], 120}

    Band.switch(band, second)
    assert_receive {:live, [%{name: :mic, opts: [amp: 0.5]}], 120}
  end

  describe "inputs" do
    @describetag :tmp_dir

    test "each pass reads the inputs as they are when it is worked out", ctx do
      {:ok, agent} = Agent.start_link(fn -> %{} end)

      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, inputs -> seq([note(inputs.cc[74] || 1, 0), rest(1)]) end)))\n"
        )

      start(song, ctx, inputs: fn _beat, _until_us -> Agent.get(agent, & &1) end)
      assert_receive {:played, _, [{:note, _, _, note, _, _}]} when note == 1.0
      Agent.update(agent, &Map.put(&1, {:cc, 74}, 64))

      notes = Enum.map(collect_until(counted(%{64 => 1})), &elem(&1, 1))
      assert List.last(notes) == 64.0
      assert notes == Enum.sort(notes)
    end

    @tag :midi
    test "a value a part of a song written as music sets is read by another loop's next pass",
         ctx do
      inputs = start_supervised!({Mx.Inputs, name: nil})

      song =
        load(ctx, """
        import Mx
        song(tempo: 600, music: together([
          part(:setter, loop(1, fn pass, _ -> seq([set(:root, 40 + pass), rest(1)]) end)),
          part(:reader, loop(1, fn _, inputs -> note(inputs.values[:root] || 1, 1) end))
        ]))
        """)

      start(song, ctx, shared(inputs))

      notes = collect_until(&Enum.any?(&1, fn {_time, note} -> note >= 40.0 end))
      [first, second | _] = notes = Enum.map(notes, &elem(&1, 1))
      assert first == 1.0
      assert second >= 40.0
      assert notes == Enum.sort(notes)
    end

    @tag :midi
    test "a set step shares its value from its beat, not from when its pass is worked out",
         ctx do
      inputs = start_supervised!({Mx.Inputs, name: nil})

      song =
        load(ctx, """
        import Mx
        song(tempo: 60, music: part(:setter, loop(1, fn _, _ -> seq([set(:root, 40), rest(1)]) end)))
        """)

      start_us = Clock.now() + 500_000
      start(song, ctx, [ahead_ms: 500, start_us: start_us] ++ shared(inputs))

      Process.sleep(50)
      assert Mx.Inputs.snapshot(inputs)[{:value, :root}] == nil
      Process.sleep(div(start_us - Clock.now(), 1000) + 50)
      assert Mx.Inputs.snapshot(inputs)[{:value, :root}] == 40
    end

    @tag :midi
    test "a loop reads its own set steps from its next pass, and a name nobody set as nil",
         ctx do
      inputs = start_supervised!({Mx.Inputs, name: nil})

      song =
        load(ctx, """
        import Mx
        song(tempo: 600, music: part(:a, loop(1, fn pass, inputs ->
          seq([set(:root, 40 + pass), note(inputs.values[:root] || 1, 0), note(inputs.values[:other] || 2, 0), rest(1)])
        end)))
        """)

      start(song, ctx, [ahead_ms: 500] ++ shared(inputs))

      notes = Enum.map(receive_notes(6), &elem(&1, 1))
      assert notes == [1.0, 2.0, 40.0, 2.0, 41.0, 2.0]
    end

    test "a loop triggered by input plays a pass at once for each input, and none on its own",
         ctx do
      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: together([part(:keys, loop(fn trigger, _ -> seq([note(trigger.note, 0), rest(1)]) end, on: :midi_note)), part(:hits, loop(fn trigger, _ -> seq([note(hd(trigger.args), 0), rest(1)]) end, on: {:osc, \"/hit\"}))]))\n"
        )

      {band, _} = start(song, ctx)
      refute_receive {:played, _, _}

      sent = Clock.now()
      send(band, {:input, {:midi_note, %{note: 64, velocity: 100}}})
      assert_receive {:played, at, [{:note, _, _, note, _, _}]} when note == 64.0
      assert Clock.now() - sent < 20_000
      assert at - sent < 20_000

      send(band, {:input, {:osc, %{address: "/other", args: [1]}}})
      send(band, {:input, {:osc, %{address: "/hit", args: [50]}}})
      assert_receive {:played, _, [{:note, _, _, note, _, _}]} when note == 50.0
      refute_receive {:played, _, _}
    end
  end

  describe "a loop started by input on a grid" do
    @describetag :tmp_dir

    # A song at tempo 120 whose loop plays one note when a MIDI note comes, and the band started
    # so that beat `beat` is now.
    defp start_at_beat(ctx, beat, grid) do
      on = if grid, do: "on: :midi_note, grid: #{grid}", else: "on: :midi_note"

      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 120, music: part(:keys, loop(fn trigger, _ -> seq([note(trigger.note, 0), rest(1)]) end, #{on})))\n"
        )

      start(song, ctx, start_us: Clock.now() - round(beat * 500_000))
    end

    defp press(band), do: send(band, {:input, {:midi_note, %{note: 64, velocity: 100}}})

    test "a grid of 1 starts the loop on the next beat", ctx do
      {band, start_us} = start_at_beat(ctx, 3.1, 1)
      press(band)
      assert_receive {:played, at, [{:note, _, _, _, _, _}]}
      assert at == start_us + 4 * 500_000
    end

    test "a grid of 4 starts the loop on the next beat that is a multiple of 4", ctx do
      {band, start_us} = start_at_beat(ctx, 2.4, 4)
      press(band)
      assert_receive {:played, at, _events}
      assert at == start_us + 4 * 500_000

      {band, start_us} = start_at_beat(ctx, 4.5, 4)
      press(band)
      refute_receive {:played, _, _}
      assert_receive {:played, at, _events}
      assert at == start_us + 8 * 500_000
    end

    test "an input 10 ms after a grid beat starts the loop on that beat", ctx do
      warned =
        capture_io(:stderr, fn ->
          {band, start_us} = start_at_beat(ctx, 4.02, 4)
          press(band)
          assert_receive {:played, at, _events}
          assert at == start_us + 4 * 500_000
          stop_quietly(band)
        end)

      assert warned =~ ~r/^loop keys is 1\d ms late$/m
    end

    test "a loop with no grid starts within 15 ms of its input", ctx do
      {band, _start_us} = start_at_beat(ctx, 3.4, nil)
      sent = Clock.now()
      press(band)
      assert_receive {:played, at, _events}
      assert at - sent < 15_000
    end

    test "a second input while the loop waits for its beat starts nothing more", ctx do
      {band, start_us} = start_at_beat(ctx, 3.05, 1)
      press(band)
      Process.sleep(200)
      press(band)
      assert_receive {:played, at, _events}
      assert at == start_us + 4 * 500_000
      refute_receive {:played, _, _}
    end

    test "a grid not above 0 is refused, naming the loop", ctx do
      path = Path.join(ctx.tmp_dir, "grid.exs")

      File.write!(
        path,
        "import Mx\nsong(tempo: 120, music: part(:pads, loop(fn _, _ -> note(60, 1) end, on: :midi_note, grid: 0)))\n"
      )

      assert {:error, message} = Song.load(path)
      assert message =~ "loop pads takes grid: in beats above 0, not 0"
    end
  end

  describe "what becomes of a saved version" do
    @describetag :tmp_dir

    setup do
      test = self()

      %{
        hand_opts: [
          hand: fn name, span, label, events, _opts ->
            send(test, {:handed, name, span, label, events})
          end,
          cut: fn name, beat -> send(test, {:cut, name, beat}) end
        ]
      }
    end

    defp four(name, pitch) do
      "part(:#{name}, loop(4, fn _, _ -> seq([note(#{pitch}, 1), rest(3)]) end))"
    end

    test "examples/choro.exs saved 4 beats into a section waits 28 beats for every part", ctx do
      {:ok, song} = Song.load("examples/choro.exs")
      beat_us = round(60_000_000 / song.tempo)

      capture_io(:stderr, fn ->
        start_us = Clock.now() - 4 * beat_us
        {band, _} = start(song, ctx, ctx.hand_opts ++ [start_us: start_us, ahead_ms: 500])
        :ok = Band.subscribe(band)
        worked_out(band)
        Band.switch(band, song)

        waits =
          for _ <- song.loops do
            assert_receive {:mx_waits, _name, wait}
            wait
          end

        assert Enum.uniq(waits) == [32]
        assert length(song.loops) == 8
      end)
    end

    test "reports when each part takes the version over, a removed part stops and an added part joins, and then that it plays",
         ctx do
      first = load(ctx, song(600, [four(:a, 60), four(:b, 62), four(:c, 64)]))
      second = load(ctx, song(600, [four(:a, 67), four(:b, 62), four(:d, 65)]))

      {band, _} = start(first, ctx)
      :ok = Band.subscribe(band)
      worked_out(band)
      Band.switch(band, second)

      assert_receive {:mx_waits, :a, 4}
      assert_receive {:mx_waits, :b, 4}
      assert_receive {:mx_waits, :c, {:stops, 4}}
      assert_receive {:mx_waits, :d, {:joins, 4}}
      assert_receive {:mx_took_over, :a, 4}
      assert_receive {:mx_took_over, :b, 4}
      assert_receive {:mx_took_over, :d, 4}
      assert_receive {:mx_took_over, :c, 4}
      assert_receive :mx_version_plays
    end

    test "a second save before the first takes over reports the same beat", ctx do
      first = load(ctx, song(60, [four(:a, 60)]))
      second = load(ctx, song(60, [four(:a, 62)]))
      third = load(ctx, song(60, [four(:a, 64)]))

      {band, _} = start(first, ctx)
      :ok = Band.subscribe(band)
      worked_out(band)
      Band.switch(band, second)
      assert_receive {:mx_waits, :a, 4}
      Process.sleep(100)
      Band.switch(band, third)
      assert_receive {:mx_waits, :a, 4}
      refute_receive {:mx_took_over, _, _}
    end

    test "a version saved during the song's last pass waits for a pass that will not come", ctx do
      first =
        load(ctx, "import Mx\nsong(tempo: 60, music: part(:a, seq([note(60, 1), rest(3)])))\n")

      second =
        load(ctx, "import Mx\nsong(tempo: 60, music: part(:a, seq([note(62, 1), rest(3)])))\n")

      {band, _} = start(first, ctx)
      :ok = Band.subscribe(band)
      assert_receive {:played, _, _}
      Band.switch(band, second)
      assert_receive {:mx_waits, :a, :never}
    end

    test "taking a version over now cuts the pass that sounds at the next beat and plays the version from there",
         ctx do
      first =
        load(
          ctx,
          song(60, [
            "part(:a, loop(8, fn _, _ -> seq(for _ <- 1..8, do: seq([note(60, 0.5), rest(0.5)])) end))"
          ])
        )

      second =
        load(
          ctx,
          song(60, [
            "part(:a, loop(8, fn _, _ -> seq(for _ <- 1..8, do: seq([note(67, 0.5), rest(0.5)])) end))"
          ])
        )

      {band, _} =
        start(first, ctx, ctx.hand_opts ++ [start_us: Clock.now() - 1_200_000])

      :ok = Band.subscribe(band)
      assert_receive {:handed, :a, {0, 8}, 0, _events}
      Band.switch(band, second)
      assert_receive {:mx_waits, :a, 8}

      assert {:ok, beat} = Band.take_over_now(band)
      assert beat in [2, 3]
      assert_receive {:cut, :a, ^beat}
      assert_receive {:handed, :a, {0, 8}, 0, events}
      assert [{first, _} | _] = events
      assert first == beat

      assert Enum.all?(events, fn {at, {:note, _, _, note, _, _}} -> at >= beat and note == 67 end)

      assert length(events) == 8 - beat
      assert_receive {:mx_took_over, :a, ^beat}
      assert_receive :mx_version_plays
    end
  end

  describe "playing a recording on a part" do
    @describetag :tmp_dir

    setup ctx do
      test = self()
      ids = :counters.new(1, [])

      opts = [
        start_fx: fn chain ->
          send(test, {:started_fx, chain})
          %{key: :voice_chain}
        end,
        new_id: fn -> :counters.add(ids, 1, 1) && :counters.get(ids, 1) end
      ]

      song =
        load(
          ctx,
          song(60, [
            "part(:voice, loop(8, fn _, _ -> seq(for _ <- 1..8, do: seq([note(67, 0.5), rest(0.5)])) end), fx: [echo: [phase: 0.75]])"
          ])
        )

      sample = %{sample: :step, channels: 1, seconds: 7.155}
      %{song: song, sample: sample, opts: opts}
    end

    test "plays a range of the recording into the part's effects from the first whole beat 150 ms away, beside the part's notes",
         ctx do
      {band, _start_us} =
        start(ctx.song, ctx, ctx.opts ++ [start_us: Clock.now() - 1_200_000])

      assert_receive {:started_fx, [echo: _]}

      asked_us = Clock.now()

      assert {:ok, beat} =
               Band.play_recording(band, :voice, ctx.sample, from: 2.447, to: 3.4, amp: 0.8)

      at_us = Band.time_at(Band.timeline(band), beat)
      assert at_us - asked_us > 150_000 and at_us - asked_us <= 1_150_000

      assert_receive {:played, ^at_us,
                      [{:sample, id, %{sample: :step}, opts, %{key: :voice_chain}}]}

      assert_in_delta opts[:start], 2.447 / 7.155, 1.0e-9
      assert_in_delta opts[:finish], 3.4 / 7.155, 1.0e-9
      assert opts[:amp] == 0.8

      assert_receive {:played, note_us, [{:note, _, _, _, _, _}]} when note_us >= at_us

      assert {:ok, again} = Band.play_recording(band, :voice, ctx.sample, from: 0.0, to: 2.4)
      again_us = Band.time_at(Band.timeline(band), again)
      assert_receive {:played, ^again_us, [{:stop, [^id]}, {:sample, other, _, _, _}]}
      assert other != id

      assert :ok = Band.stop_recording(band, :voice)
      assert_receive {:played, stop_us, [{:stop, [^other]}]}
      assert stop_us - Clock.now() < 1_000_000
    end

    test "a part the song does not have is refused, naming it", ctx do
      {band, _start_us} = start(ctx.song, ctx, ctx.opts)

      assert Band.play_recording(band, :no_such_part, ctx.sample, []) ==
               {:error, "the song has no part named no_such_part"}

      assert Band.stop_recording(band, :no_such_part) ==
               {:error, "the song has no part named no_such_part"}
    end
  end

  describe "trying a synth or options on a part" do
    @describetag :tmp_dir

    setup ctx do
      test = self()

      opts = [
        hand: fn name, span, label, events, _opts ->
          send(test, {:handed, name, span, label, events})
        end,
        cut: fn name, beat -> send(test, {:cut, name, beat}) end
      ]

      flute =
        "part(:flute, loop(8, fn _, _ -> seq(for _ <- 1..8, do: seq([note(72, 0.5, amp: 0.5, breath: 0.3, pan: -0.5), rest(0.5)])) end), synth: :flute)"

      {band, _start_us} =
        start(
          load(ctx, song(60, [flute])),
          ctx,
          opts ++ [start_us: Clock.now() - 1_200_000]
        )

      assert_receive {:handed, :flute, {0, 8}, 0, _events}
      %{band: band, flute: flute, hand_opts: opts}
    end

    # The beat a trial is heard from, and the synth and options of the notes handed from there.
    defp tried_notes do
      assert_receive {:cut, :flute, beat}
      assert_receive {:handed, :flute, _span, _label, events}
      assert Enum.all?(events, fn {at, _event} -> at >= beat end)
      for {_at, {:note, _, synth, _, params, _}} <- events, do: {synth, Map.new(params)}
    end

    test "another synth plays the part's next notes within a bar, then another, then the song's again",
         %{band: band} do
      assert Band.try_part(band, :flute, synth: :clarinet) == :ok
      assert [{:clarinet, _} | _] = notes = tried_notes()
      assert Enum.all?(notes, &match?({:clarinet, _}, &1))

      assert Band.try_part(band, :flute, synth: :trumpet) == :ok
      assert Enum.all?(tried_notes(), &match?({:trumpet, _}, &1))

      assert Band.stop_trying(band, :flute) == :ok
      assert Enum.all?(tried_notes(), &match?({:flute, _}, &1))
    end

    test "an option tried with another synth changes only itself", %{band: band} do
      :ok = Band.try_part(band, :flute, synth: :clarinet)
      tried_notes()
      assert Band.try_part(band, :flute, vel: 0.8) == :ok

      for {synth, params} <- tried_notes() do
        assert synth == :clarinet
        assert %{vel: 0.8, amp: 0.5, breath: 0.3, pan: -0.5} = params
      end
    end

    test "an option the tried synth does not take is left out, and named once", %{band: band} do
      warned =
        capture_io(:stderr, fn ->
          :ok = Band.try_part(band, :flute, synth: :tri)

          assert Enum.all?(tried_notes(), fn {:tri, params} ->
                   not is_map_key(params, :breath)
                 end)

          Process.sleep(100)
        end)

      assert warned == "loop flute: :tri takes no option breath, so it is left out\n"
    end

    test "a part, synth or option that does not exist is refused, naming it", %{band: band} do
      assert Band.try_part(band, :no_such_part, synth: :clarinet) ==
               {:error, "the song has no part named no_such_part"}

      assert Band.try_part(band, :flute, synth: :kazoo) ==
               {:error, "there is no synth named kazoo"}

      assert Band.try_part(band, :flute, wobble: 1) == {:error, "flute takes no option wobble"}
      refute_receive {:cut, _, _}
    end

    test "clarinet tried on examples/choro.exs's flute plays its next notes within a bar, and leaves the file as it is",
         ctx do
      {:ok, song} = Song.load("examples/choro.exs")
      before = File.read!("examples/choro.exs")

      capture_io(:stderr, fn ->
        {band, _} = start(song, ctx, ctx.hand_opts)
        assert_receive {:handed, :flute, _span, _label, _events}
        assert Band.try_part(band, :flute, synth: :clarinet) == :ok
        assert_receive {:cut, :flute, beat}
        assert_receive {:handed, :flute, _span, _label, events}
        notes = for {at, {:note, _, synth, _, _, _}} <- events, do: {at, synth}
        assert [{first, _} | _] = notes
        assert first - beat < 4
        assert Enum.all?(notes, &match?({_, :clarinet}, &1))
        refute_received {:cut, :clarinet, _}
      end)

      assert File.read!("examples/choro.exs") == before
    end

    test "what is tried holds through a saved version with another tempo", ctx do
      :ok = Band.try_part(ctx.band, :flute, synth: :clarinet)
      tried_notes()
      Band.switch(ctx.band, load(ctx, song(90, [ctx.flute])))
      [loop] = Band.loops(ctx.band)
      send(loop, {:mx_pass_ending, :flute, 8.0})
      assert_receive {:handed, :flute, {8, 16}, 1, events}
      assert Enum.all?(events, &match?({_, {:note, _, :clarinet, _, _, _}}, &1))
    end
  end

  describe "midi and osc" do
    @describetag :tmp_dir

    test "a loop hands its MIDI and OSC steps to out, stamped with their beat", ctx do
      test = self()
      out = fn at, message -> send(test, {:out, at, message}) end

      song =
        load(ctx, """
        import Mx

        song(
          tempo: 600,
          osc_to: {"127.0.0.1", 9000},
          music:
            part(
              :a,
              loop(2, fn _, _ ->
                at([{0, midi(60, 1.5)}, {0, midi(64, 0.5, velocity: 90, channel: 2)}, {1, midi_cc(74, 64)}, {1, osc("/hello", [1, "a"])}], 2)
              end),
              midi: "mx test port"
            )
        )
        """)

      {_band, start_us} = start(song, ctx, out: out)
      beat = &(start_us + round(&1 * 100_000))

      assert_receive {:out, at, {:midi, "mx test port", <<0x90, 60, 100>>}}
      assert at == beat.(0)
      assert_receive {:out, at, {:midi, "mx test port", <<0x91, 64, 90>>}}
      assert at == beat.(0)
      assert_receive {:out, at, {:midi, "mx test port", <<0x81, 64, 0>>}}
      assert at == beat.(0.5)
      assert_receive {:out, at, {:midi, "mx test port", <<0xB0, 74, 64>>}}
      assert at == beat.(1)
      assert_receive {:out, at, {:osc, {"127.0.0.1", 9000}, packet}}
      assert at == beat.(1)
      assert OSC.decode(packet) == {"/hello", [1, "a"]}
      assert_receive {:out, at, {:midi, "mx test port", <<0x80, 60, 0>>}}
      assert at == beat.(1.5)
      assert_receive {:out, at, {:midi, "mx test port", <<0x90, 60, 100>>}}
      assert at == beat.(2)
    end

    test "MIDI and OSC of a song written as music go to out at their beats", ctx do
      test = self()
      out = fn at, message -> send(test, {:out, at, message}) end

      song =
        load(ctx, """
        import Mx
        song(tempo: 600, osc_to: {"127.0.0.1", 9000}, music: repeat(part(:synth, seq([
          midi(60, 2, velocity: 90),
          midi_cc(74, 64),
          osc("/hello", [1, "a"]),
          rest(2)
        ]), midi: "mx test port")))
        """)

      {_band, start_us} = start(song, ctx, out: out)
      beat = &(start_us + round(&1 * 100_000))

      assert_receive {:out, at, {:midi, "mx test port", <<0x90, 60, 90>>}}
      assert at == beat.(0)
      assert_receive {:out, at, {:midi, "mx test port", <<0xB0, 74, 64>>}}
      assert at == beat.(2)
      assert_receive {:out, at, {:osc, {"127.0.0.1", 9000}, packet}}
      assert at == beat.(2)
      assert OSC.decode(packet) == {"/hello", [1, "a"]}
      assert_receive {:out, at, {:midi, "mx test port", <<0x80, 60, 0>>}}
      assert at == beat.(2)
    end

    test "a note off after the end of the pass holds up nothing that comes before it", ctx do
      test = self()
      out = fn at, message -> send(test, {:out, at, message}) end

      song =
        load(
          ctx,
          "import Mx\nsong(tempo: 600, music: part(:a, loop(1, fn _, _ -> at([{0, midi(60, 8)}, {0, note(72, 0)}], 1) end)))\n"
        )

      {_band, start_us} = start(song, ctx, out: out)

      times = for {time, 72.0} <- collect_until(counted(%{72 => 3})), do: time
      assert Enum.take(times, 3) == [start_us, start_us + 100_000, start_us + 200_000]
    end
  end

  describe "control" do
    @describetag :tmp_dir

    test "a control step changes the sound it names at its beat, and other notes keep no id",
         ctx do
      song =
        load(ctx, """
        import Mx

        song(
          tempo: 600,
          music: part(:a, loop(2, fn _, _ -> seq([note(60, 0, sustain: 4, changes: [{1, note: 65, amp: 0}]), note(72, 0), rest(2)]) end))
        )
        """)

      {_band, start_us} = start(song, ctx)

      messages =
        messages_until(fn messages ->
          length(for {_, {:set, _, _}} <- messages, do: true) >= 2
        end)

      starts = for {time, {:note, id, :tri, note, _, nil}} <- messages, do: {time, id, note}
      controls = for {time, {:set, target, params}} <- messages, do: {time, target, params}

      [{^start_us, first, 60}, {^start_us, nil, 72}, {second_us, second, 60} | _] = starts
      assert first != nil
      assert second not in [nil, first]
      assert second_us == start_us + 200_000

      assert [{time, {:sounds, [^first]}, [note: 65, amp: 0]}, {_, {:sounds, [^second]}, _} | _] =
               controls

      assert time == start_us + 100_000
    end

    test "slides are measured in beats, in play and in control", ctx do
      song =
        load(ctx, """
        import Mx

        song(
          tempo: 120,
          music: part(:a, loop(2, fn _, _ -> seq([note(60, 0, note_slide: 1, changes: [{1, note: 65, note_slide: 2}]), rest(2)]) end))
        )
        """)

      start(song, ctx)

      messages =
        messages_until(&Enum.any?(&1, fn message -> match?({_, {:set, _, _}}, message) end))

      assert [{_, {:note, _, _, _, _, _} = params} | _] = messages
      assert params_map(params)[:note_slide] == 0.5
      sets = for {_, {:set, _, params}} <- messages, do: params
      assert [params | _] = sets
      assert params == [note: 65, note_slide: 1.0]
    end

    test "a control step on an effect changes the loop's effect at its beat", ctx do
      test = self()

      start_fx = fn chain ->
        send(test, {:fx_started, chain})
        %{group: 1001, bus: 64, nodes: [1002, 1003]}
      end

      song =
        load(ctx, """
        import Mx

        song(
          tempo: 600,
          music: part(:a, loop(4, fn _, _ -> seq([note(60, 0), rest(2), change({:a, :reverb}, mix: 0), rest(2)]) end), fx: [:echo, :reverb])
        )
        """)

      {_band, start_us} = start(song, ctx, start_fx: start_fx, stop_fx: fn _, _ -> :ok end)

      messages =
        messages_until(&Enum.any?(&1, fn message -> match?({_, {:set, _, _}}, message) end))

      sets = for {time, {:set, target, params}} <- messages, do: {time, target, params}
      assert [{time, {:effect, %{nodes: [1002, 1003]}, 1}, [mix: 0]} | _] = sets

      assert time == start_us + 200_000
    end

    test "a change sliding a tremolo's depth to 0 over a beat reaches the tremolo at its beat",
         ctx do
      test = self()

      start_fx = fn chain ->
        send(test, {:fx_started, chain})
        %{group: 1001, bus: 64, nodes: [1002]}
      end

      song =
        load(ctx, """
        import Mx

        song(
          tempo: 600,
          music: part(:a, loop(4, fn _, _ -> seq([note(60, 0), rest(2), change({:a, :tremolo}, depth: 0, depth_slide: 1), rest(2)]) end), fx: [tremolo: [depth: 1]])
        )
        """)

      {_band, start_us} = start(song, ctx, start_fx: start_fx, stop_fx: fn _, _ -> :ok end)

      messages =
        messages_until(&Enum.any?(&1, fn message -> match?({_, {:set, _, _}}, message) end))

      sets = for {time, {:set, target, params}} <- messages, do: {time, target, params}
      assert [{time, {:effect, %{nodes: [1002]}, 0}, [depth: 0, depth_slide: slide]} | _] = sets
      assert_in_delta slide, 0.1, 1.0e-6
      assert time == start_us + 200_000
    end
  end

  @tag :tmp_dir
  test "a new version whose loop plays a sample file mx cannot read is refused, naming the loop, the file and why, and the previous version keeps playing",
       ctx do
    kick = Path.join(ctx.tmp_dir, "kick.wav")
    File.write!(kick, "not a sound\n")

    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end)))\n"
      )

    broken =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(1, fn _, _ -> seq([sample(#{inspect(kick)}, 0), rest(1)]) end)))\n"
      )

    {band, _} = start(first, ctx)
    receive_notes(1)

    output =
      capture_io(:stderr, fn ->
        Band.switch(band, broken)
        assert Enum.map(receive_notes(5), &elem(&1, 1)) == List.duplicate(60.0, 5)
      end)

    assert output =~ "sample file #{kick} cannot play: it is not a FLAC, WAV or AIFF file"
    assert output =~ "melody"
    assert output =~ "keeps playing"
  end

  @tag :tmp_dir
  test "a new version whose pass fails is refused, and the previous version keeps playing", ctx do
    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end)))\n"
      )

    broken =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:melody, loop(1, fn _, _ -> raise(\"boom\") end)))\n"
      )

    {band, _} = start(first, ctx)
    receive_notes(1)

    output =
      capture_io(:stderr, fn ->
        Band.switch(band, broken)
        assert Enum.map(receive_notes(5), &elem(&1, 1)) == List.duplicate(60.0, 5)
      end)

    assert output =~ "boom"
    assert output =~ "keeps playing"
  end

  @tag :tmp_dir
  @tag :realtime
  test "a pass that falls behind prints a warning naming the loop, and the loop keeps playing",
       ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:slow, loop(1, fn pass, _ -> Process.sleep(if(pass == 1, do: 60, else: 0)); seq([note(60, 0), rest(1)]) end)))\n"
      )

    output =
      capture_io(:stderr, fn ->
        start(song, ctx)
        receive_notes(4)
      end)

    assert output =~ ~r/loop slow is \d+ ms late/
  end

  @tag :tmp_dir
  @tag :realtime
  test "a late pass drops the notes more than a quarter beat late, sends the rest, and the next pass plays on time",
       ctx do
    song =
      load(ctx, """
      import Mx

      song(
        tempo: 600,
        music:
          together([
            part(:slow, loop(6, fn pass, _ ->
              if pass == 1, do: Process.sleep(320)
              seq(for note <- 60..65, do: seq([note(note, 0), rest(1)]))
            end)),
            part(:steady, loop(1, fn _, _ -> seq([note(40, 0), rest(1)]) end))
          ])
      )
      """)

    output =
      capture_io(:stderr, fn ->
        {_band, start_us} = start(song, ctx)
        send(self(), {:start_us, start_us})
        send(self(), {:notes, collect_until(counted(%{65 => 3, 40 => 18}))})
      end)

    assert_received {:start_us, start_us}
    assert_received {:notes, notes}
    pass_us = fn pass -> start_us + pass * 600_000 end

    assert output =~ ~r/loop slow is \d+ ms late and dropped 3 notes\n/
    refute output =~ "steady"

    slow = for {time, note} <- notes, note >= 60.0, do: {time, round(note)}

    second_pass = for note <- 63..65, do: {pass_us.(1) + (note - 60) * 100_000, note}
    third_pass = for note <- 60..65, do: {pass_us.(2) + (note - 60) * 100_000, note}

    assert Enum.filter(slow, fn {time, _} -> time >= pass_us.(1) and time < pass_us.(2) end) ==
             second_pass

    assert Enum.filter(slow, fn {time, _} -> time >= pass_us.(2) and time < pass_us.(3) end) ==
             third_pass

    slow_times = Enum.map(slow, &elem(&1, 0))
    assert slow_times == Enum.uniq(slow_times)

    steady = times(notes, 40)
    assert steady == Enum.map(0..(length(steady) - 1), &(start_us + &1 * 100_000))
    assert length(steady) >= 14
  end

  defp first_params(ctx, tempo, opts) do
    song =
      load(
        ctx,
        song(tempo, ["part(:a, loop(1, fn _, _ -> seq([note(60, 0, #{opts}), rest(1)]) end))"])
      )

    {band, _} = start(song, ctx)
    assert_receive {:played, _, [{:note, _, _, _, _, _} = params]}
    Process.unlink(band)
    GenServer.stop(band, :shutdown)
    params_map(params) |> Map.new(fn {key, value} -> {key, Float.round(value, 6)} end)
  end

  # An event's options, with its pitch as note, all as floats.
  defp params_map({:note, _, _, note, params, _}) do
    pitch = if note == nil, do: [], else: [note: note]
    Map.new(pitch ++ params, fn {key, value} -> {key, value / 1} end)
  end

  defp params_map({:sample, _, _, params, _}) do
    Map.new(params, fn {key, value} -> {key, value / 1} end)
  end

  @tag :tmp_dir
  test "a song written as music ends after its last section, and says so", ctx do
    song = load(ctx, "import Mx\nsong(tempo: 6000, music: part(:melody, seq(c4: 1, e4: 1)))\n")
    test = self()
    start(song, ctx, on_end: fn -> send(test, :ended) end)

    assert Enum.map(receive_notes(2), &elem(&1, 1)) == [60.0, 64.0]
    assert_receive :ended
    refute_receive {:played, _, [{:note, _, _, _, _, _}]}
  end

  @tag :tmp_dir
  test "a saved song written as music takes over at the end of the section playing", ctx do
    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: repeat(seq([part(:melody, seq(c4: 1)), part(:melody, seq(d4: 1))])))\n"
      )

    second =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: repeat(seq([part(:melody, seq(g4: 1)), part(:melody, seq(e4: 1))])))\n"
      )

    {band, _start_us} = start(first, ctx)
    assert [{_, 60.0}] = receive_notes(1)
    Band.switch(band, second)

    assert Enum.map(receive_notes(2), &elem(&1, 1)) == [64.0, 67.0]
  end

  @tag :tmp_dir
  test "a part a saved song written as music adds joins at the next section, with that section's notes",
       ctx do
    first =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: repeat(seq([part(:melody, seq(c4: 1)), part(:melody, seq(d4: 1))])))\n"
      )

    second =
      load(ctx, """
      import Mx
      song(tempo: 600, music: repeat(seq([
        together([part(:melody, seq(c4: 1)), part(:harmony, seq(g5: 1))]),
        together([part(:melody, seq(d4: 1)), part(:harmony, seq(a5: 1))])
      ])))
      """)

    {band, _start_us} = start(first, ctx)
    assert [{_, 60.0}] = receive_notes(1)
    Band.switch(band, second)

    [{d4_time, 62.0}, {a5_time, 81.0}] = Enum.sort_by(receive_notes(2), &elem(&1, 1))
    assert d4_time == a5_time
  end

  @tag :tmp_dir
  test "a loop of a song written as music with times: plays its passes and the song ends", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 6000, music: part(:drums, loop(1, fn pass, _ -> note(60 + pass, 1) end, times: 3)))\n"
      )

    test = self()
    start(song, ctx, on_end: fn -> send(test, :ended) end)

    assert Enum.map(receive_notes(3), &elem(&1, 1)) == [60.0, 61.0, 62.0]
    assert_receive :ended
  end

  @tag :tmp_dir
  test "a loop of a song written as music on: plays a pass at once for each input", ctx do
    song =
      load(
        ctx,
        "import Mx\nsong(tempo: 600, music: part(:keys, loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note)))\n"
      )

    {band, _} = start(song, ctx)
    refute_receive {:played, _, _}

    sent = Clock.now()
    send(band, {:input, {:midi_note, %{note: 64, velocity: 100}}})
    assert_receive {:played, at, [{:note, _, _, note, _, _}]} when note == 64.0
    assert at - sent < 20_000
  end

  @tag :tmp_dir
  test "a loop of a song written as music that raises plays its next pass, and the other parts play on",
       ctx do
    song =
      load(ctx, """
      import Mx
      song(tempo: 600, music: together([
        part(:lead, loop(1, fn pass, _ -> if(pass == 1, do: raise("broken"), else: note(70, 1)) end)),
        part(:bass, loop(1, fn _, _ -> note(40, 1) end))
      ]))
      """)

    output =
      capture_io(:stderr, fn ->
        start(song, ctx)
        notes = Enum.map(receive_notes(8), &elem(&1, 1))
        assert Enum.count(notes, &(&1 == 40.0)) >= 4
        assert Enum.count(notes, &(&1 == 70.0)) >= 2
      end)

    assert output =~ "part lead: broken"
  end

  defp releases_until(done?) do
    releases = fn played ->
      for {_time, params} <- played, do: Float.round(params_map(params)[:release], 6)
    end

    releases.(params_until(&done?.(releases.(&1))))
  end

  defp params_until(done?, played \\ []) do
    sorted = Enum.sort(played)

    if done?.(sorted) do
      sorted
    else
      assert_receive {:played, time, [{:note, _, _, _, _, _} = params]}
      params_until(done?, [{time, params} | played])
    end
  end

  defp start(song, ctx, opts \\ []) do
    start_us = Clock.now() + 20_000
    opts = Keyword.merge([song: song, play: ctx.play, ahead_ms: 20, start_us: start_us], opts)
    {:ok, band} = Band.start_link(opts)
    driven(band, ctx)
    {band, opts[:start_us]}
  end

  # Has every loop of the band work out what is due now, as a band playing live has each do as it
  # starts.
  defp worked_out(band), do: Enum.each(loops(band), &tick/1)

  defp driven(band, ctx) do
    if driver = ctx[:driver], do: send(driver, {:band, band})
    band
  end

  # Ticks every loop of the test's bands, as a render does, then moves the clock on to the first
  # loop's wake, by at least a millisecond and never past the system's time.
  # The clock never passes a time a loop has not worked out, so no loop is late on a slow machine.
  defp drive(bands) do
    bands =
      receive do
        {:band, band} -> [band | bands]
      after
        0 -> bands
      end

    bands = Enum.filter(bands, &Process.alive?/1)
    wakes = for band <- bands, pid <- loops(band), do: tick(pid)
    now = Clock.now()
    next = max(Enum.min(wakes, fn -> :infinity end), now + 1000)
    Clock.advance(max(now, min(next, System.os_time(:microsecond))))
    Process.sleep(1)
    drive(bands)
  end

  defp loops(band) do
    Band.loops(band)
  catch
    :exit, _ -> []
  end

  defp tick(pid) do
    send(pid, :tick)
    :sys.get_state(pid).wake_us || :infinity
  catch
    :exit, _ -> :infinity
  end

  defp shared(inputs) do
    [
      inputs: &Mx.Inputs.snapshot_at(inputs, &1, &2),
      set: &Mx.Inputs.put(inputs, &1, &2, &3, &4),
      worked_out: &Mx.Inputs.worked_out(inputs, &1, &2)
    ]
  end

  defp prepared(song, buffers) do
    %{song | loops: Enum.map(song.loops, &%{&1 | buffers: buffers})}
  end

  defp receive_notes(count) do
    for _ <- 1..count do
      assert_receive {:played, time, [{:note, _, _, note, _, _}]}
      {time, pitch(note)}
    end
  end

  defp collect_through(note, notes \\ []) do
    assert_receive {:played, time, [{:note, _, _, received, _, _}]}

    notes = [{time, pitch(received)} | notes]
    if received == note, do: notes, else: collect_through(note, notes)
  end

  defp pitch(nil), do: nil
  defp pitch(note), do: note / 1

  # Receives notes until `done?` holds for every note received, in time order.
  defp collect_until(done?, notes \\ []) do
    sorted = Enum.sort(notes)

    if done?.(sorted) do
      sorted
    else
      assert_receive {:played, time, [{:note, _, _, note, _, _}]}
      collect_until(done?, [{time, pitch(note)} | notes])
    end
  end

  defp counted(wanted) do
    fn notes -> Enum.all?(wanted, fn {note, count} -> length(times(notes, note)) >= count end) end
  end

  defp targets_until(done?, targets \\ []) do
    sorted = Enum.sort_by(targets, & &1.time)

    if done?.(sorted) do
      sorted
    else
      assert_receive {:played, time, [{:note, _, _, note, _, chain}]}
      targets_until(done?, [%{time: time, chain: chain, note: note} | targets])
    end
  end

  defp messages_until(done?, messages \\ []) do
    if done?.(messages) do
      Enum.sort_by(messages, &elem(&1, 0))
    else
      assert_receive {:played, time, played}
      timed = for message <- played, do: {time, message}
      messages_until(done?, messages ++ timed)
    end
  end

  defp times(notes, note) do
    for {time, ^note} <- Enum.map(notes, &round_note/1), do: time
  end

  defp round_note({time, note}), do: {time, round(note)}

  # The time of the note where the gap to the next note turns from `gap_before` to `gap_after`.
  defp tempo_change(times, gap_before, gap_after) do
    times
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.find_value(fn [a, b, c] -> if b - a == gap_before and c - b == gap_after, do: b end)
  end

  defp click(pitch \\ 60) do
    "part(:a, loop(1, fn _, _ -> seq([note(#{pitch}, 0), rest(1)]) end))"
  end

  # Ends a band and its loops at once, so no loop is left calling it.
  defp stop_quietly(band) do
    Process.unlink(band)
    Process.exit(band, :kill)
  end

  defp song(tempo, parts) do
    music = Enum.join(parts, ", ")
    "import Mx\nsong(tempo: #{tempo}, music: together([#{music}]))\n"
  end

  defp load(%{tmp_dir: dir}, content) do
    path = Path.join(dir, "song_#{System.unique_integer([:positive])}.exs")
    File.write!(path, content)
    {:ok, song} = Song.load(path)
    song
  end
end
