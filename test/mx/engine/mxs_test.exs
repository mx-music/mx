defmodule Mx.Engine.MxsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.Engine.Mxs
  alias Mx.{Song, Synths}

  describe "events" do
    test "a note names mxs's synth, with its pitch as its note option, and its chain's key" do
      assert Mxs.event({:note, 7, :piano, 60, [vel: 1, amp: 0.5], %{key: 3}}) ==
               {:note, 7, "piano", [{"note", 60.0}, {"vel", 1.0}, {"amp", 0.5}], 3}
    end

    test "a drum's own pitch sends no note, and a named option sends its name" do
      assert Mxs.event({:note, nil, :tabla, nil, [bol: :ghe], nil}) ==
               {:note, nil, "tabla", [{"bol", "ghe"}], nil}
    end

    test "a sample plays from the number mxs loaded it as" do
      assert Mxs.event({:sample, nil, %{sample: 4, channels: 2}, [rate: 1], nil}) ==
               {:sample, nil, 4, [{"rate", 1.0}], nil}
    end

    test "a change reaches its sounds, every note in a chain, or one effect of it" do
      chain = %{key: 3}

      assert Mxs.event({:set, {:sounds, [1, 2]}, [amp: 0]}) ==
               {:set, {:sounds, [1, 2]}, [{"amp", 0.0}]}

      assert Mxs.event({:set, {:part, chain}, [cutoff: 80]}) ==
               {:set, {:part, 3}, [{"cutoff", 80.0}]}

      assert Mxs.event({:set, {:effect, chain, 1}, [mix: 0.5]}) ==
               {:set, {:effect, 3, 1}, [{"mix", 0.5}]}
    end
  end

  describe "the synths mxs has" do
    test "are the ones a song can play, with the options each declares, amp and pan included" do
      assert "piano" in Synths.synths()
      assert "berimbau" in Synths.synths()
      assert Synths.option?(:piano, :pedal)
      assert Synths.option?(:piano, :pan)
      refute Synths.option?(:berimbau, :sustain)
      assert Synths.option?(:stereo_player, :rate)
    end

    @tag :tmp_dir
    test "a song that gives a synth an option it does not declare fails when it loads", ctx do
      path = Path.join(ctx.tmp_dir, "song.exs")

      File.write!(
        path,
        "import Mx\n\nsong(music: part(:keys, note(:c4, 1, rooom: 1), synth: :piano))\n"
      )

      assert Song.load(path) ==
               {:error,
                "#{path}:3: part keys: synth piano has no option rooom, in note(60, 1, rooom: 1)"}

      File.write!(
        path,
        "import Mx\n\nsong(music: part(:keys, note(:c4, 1, pedal: 1), synth: :piano))\n"
      )

      assert {:ok, _} = Song.load(path)
    end
  end

  describe "rendering offline" do
    test "renders a note the same on every run" do
      first = Mxs.render_note(:piano, [note: 60, sustain: 0.5, release: 0.3], 1, nil, [])
      assert length(first) == 48_000
      assert Enum.any?(first, &(abs(&1) > 0.01))
      assert first == Mxs.render_note(:piano, [note: 60, sustain: 0.5, release: 0.3], 1, nil, [])
    end

    test "applies changes to the note while it renders" do
      quiet = Mxs.render_note(:berimbau, [amp: 1], 1, nil, [{0.1, [amp: 0]}])
      assert Enum.all?(Enum.slice(quiet, 9600, 1000), &(&1 == 0.0))
    end

    test "renders through an empty effect chain as the note alone" do
      {left, right} = Mxs.render_through(:berimbau, [], 0.5, nil, [])
      assert left == right
      assert left == Mxs.render_note(:berimbau, [], 0.5, nil, [])
    end
  end

  test "a panic in the engine's Rust code raises in Elixir, and the BEAM carries on" do
    assert_raise ErlangError, ~r/nif_panicked/, fn -> Mxs.Native.panic_on_purpose() end
    assert Mxs.render_note(:berimbau, [], 0.1, nil, []) != []
  end

  @tag :tmp_dir
  test "given record:, it writes the output to a WAV file mx reports on, closed on stop", %{
    tmp_dir: dir
  } do
    wav = Path.join(dir, "session.wav")
    start_supervised!({Mxs, live: false, record: wav})
    stop_supervised!(Mxs)

    assert Mx.Recording.report(wav) == ["Recorded 0.0 seconds to #{wav}, peaking at -inf dB."]
  end

  @tag :tmp_dir
  test "a recording it cannot write stops it from starting, naming why", %{tmp_dir: dir} do
    wav = Path.join([dir, "missing", "session.wav"])
    Process.flag(:trap_exit, true)

    assert {:error, "mxs could not record to " <> _} =
             Mxs.start_link(live: false, record: wav)
  end

  describe "playing" do
    setup do
      start_supervised!({Mxs, live: false})
      :ok
    end

    test "a value outside its range is held to it, and the output says so once" do
      at = System.os_time(:microsecond)

      output =
        capture_io(:stderr, fn ->
          :ok = Mxs.play(at, [{:note, nil, :piano, 60, [vel: 1.5], nil}])
          :ok = Mxs.play(at, [{:note, nil, :piano, 62, [vel: 1.5], nil}])
        end)

      assert output == "piano's option vel was held to its range, 0.05 to 1\n"
    end

    test "a chord of fifty notes handed over does not hold up another process, with one scheduler" do
      online = :erlang.system_flag(:schedulers_online, 1)
      on_exit(fn -> :erlang.system_flag(:schedulers_online, online) end)
      test = self()
      ticker = spawn_link(fn -> tick(test, System.monotonic_time(:microsecond), 0) end)
      Process.sleep(20)
      chord = for note <- 21..70, do: {:note, nil, :piano, note, [], nil}
      at = System.os_time(:microsecond)
      {call_us, :ok} = :timer.tc(fn -> Mxs.play(at, chord) end)
      send(ticker, :stop)
      assert_receive {:latest, late_us}

      # Building fifty piano voices takes tens of milliseconds, and the ticker must not wait.
      assert call_us > 10_000
      assert late_us < call_us / 4
    end

    test "ids count up for the sounds a later change reaches" do
      assert Mxs.new_id() + 1 == Mxs.new_id()
    end

    test "an effect it does not have is refused, naming it" do
      assert_raise ArgumentError, "no effect named warble", fn ->
        Mxs.start_fx([{:warble, []}])
      end
    end

    test "live audio without input says to restart, and plays nothing" do
      live = %Song.Live{name: :mic, opts: [pan: 0.5]}

      output = capture_io(:stderr, fn -> assert Mxs.set_live([live], 60) == :ok end)

      assert output ==
               "live_audio needs audio input, which mxs started without; restart mx to hear it.\n"

      assert capture_io(:stderr, fn -> assert Mxs.set_live([], 60) == :ok end) == ""
    end

    @tag :tmp_dir
    test "a sample recorded in place of the input writes a stereo WAV file mx reads", %{
      tmp_dir: dir
    } do
      wav = Path.join(dir, "take.wav")
      at = System.os_time(:microsecond)

      assert Mxs.record_input(wav, {:sample, "test/support/samples/sn_dolf.flac"}, at) == :ok
      assert Mxs.stop_input() == :ok
      assert Mxs.stop_input() == :ok

      assert {:ok, %{rate: 48_000, samples: []}} = Mx.Audio.read(wav)

      assert <<"RIFF", _::32, "WAVE", "fmt ", _::32, 0xFFFE::little-16, 2::little-16, _::binary>> =
               File.read!(wav)
    end

    @tag :tmp_dir
    test "a recording it cannot make is refused, naming why", %{tmp_dir: dir} do
      at = System.os_time(:microsecond)
      nowhere = Path.join([dir, "missing", "take.wav"])
      wav = Path.join(dir, "take.wav")

      assert {:error, "mxs could not record to " <> _} =
               Mxs.record_input(nowhere, {:sample, "test/support/samples/sn_dolf.flac"}, at)

      output =
        capture_io(:stderr, fn ->
          assert Mxs.record_input(wav, {:sample, "no/such.wav"}, at) ==
                   {:error, "mxs could not load no/such.wav"}
        end)

      assert output =~ "mxs could not load sample no/such.wav"

      assert Mxs.record_input(wav, {:input, 1}, at) ==
               {:error, "mxs could not record to #{wav}: the sound card has no input 1"}
    end
  end

  describe "an engine that renders offline" do
    setup do
      start_supervised!({Mxs, live: false})
      :ok
    end

    test "says its rate, and has no device and no delay" do
      assert Mxs.output(self()) == %{device: nil, rate: 48_000.0, delay_ms: nil}
    end

    test "tells whoever asked for its output when it reports another one" do
      Mxs.output(self())

      send(
        Process.whereis(Mxs),
        {:mxs_report, {:output, 1.0, "External Headphones", 44_100.0, 7.0}}
      )

      assert_receive {:mx_output, %{device: "External Headphones", rate: 44_100.0, delay_ms: 7.0}}
      assert Mxs.output(self()).device == "External Headphones"
    end

    test "sends the notes that sound once for each second, 0 with nothing playing, until told to stop" do
      at = System.os_time(:microsecond)
      :ok = Mxs.voices(self())
      Mxs.render_to(at + 1_500_000)
      assert_receive {:mx_voices, 0}

      :ok =
        Mxs.play(
          at + 2_000_000,
          for(note <- [60, 64, 67], do: {:note, nil, :piano, note, [], nil})
        )

      Mxs.render_to(at + 3_500_000)
      assert_receive {:mx_voices, 3}

      :ok = Mxs.stop_voices(self())
      Process.sleep(150)
      flush_voices()
      Mxs.render_to(at + 6_500_000)
      refute_receive {:mx_voices, _}, 300
      assert :sys.get_state(Mxs).asked == %{}
    end

    test "stops counting voices once whoever asked is gone" do
      asker = spawn(fn -> Process.sleep(:infinity) end)
      :ok = Mxs.voices(asker)
      assert %{"voices" => _} = :sys.get_state(Mxs).asked
      Process.exit(asker, :kill)
      Process.sleep(50)
      assert :sys.get_state(Mxs).asked == %{}
    end
  end

  describe "parts" do
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      wav = Path.join(dir, "parts.wav")
      start_supervised!({Mxs, live: false, record: wav, fade_ms: 0})
      %{wav: wav, at: System.os_time(:microsecond)}
    end

    test "a muted part is silent, the note handed over before included, and is heard again when unmuted",
         %{wav: wav, at: at} do
      lead = Mxs.start_part(:lead, [])
      :ok = Mxs.play(at, [{:note, nil, :saw, 60, [sustain: 5], lead}])
      Mxs.render_to(at + 1_000_000)
      :ok = Mxs.mute(:lead, true)
      Mxs.render_to(at + 2_000_000)
      :ok = Mxs.mute("lead", false)
      Mxs.render_to(at + 3_000_000)

      assert [heard, muted, back] = peaks(wav, [{0.1, 1.0}, {1.1, 2.0}, {2.1, 3.0}])
      assert heard > 0.05
      assert muted == 0.0
      assert_in_delta back, heard, heard / 2
    end

    test "with a part soloed only it is heard, and every part again once no part is", %{
      wav: wav,
      at: at
    } do
      lead = Mxs.start_part(:lead, [])
      Mxs.start_part(:bass, [])
      :ok = Mxs.play(at, [{:note, nil, :saw, 60, [sustain: 5], lead}])
      :ok = Mxs.solo(:bass, true)
      Mxs.render_to(at + 1_000_000)
      :ok = Mxs.solo(:lead, true)
      Mxs.render_to(at + 2_000_000)
      :ok = Mxs.solo(:lead, false)
      Mxs.render_to(at + 3_000_000)
      :ok = Mxs.solo(:bass, false)
      Mxs.render_to(at + 4_000_000)

      assert [other, both, other_again, none] =
               peaks(wav, [{0.1, 1.0}, {1.1, 2.0}, {2.1, 3.0}, {3.1, 4.0}])

      assert other == 0.0 and other_again == 0.0
      assert both > 0.05 and none > 0.05
    end

    # The engine mutes over 10 ms, and a loop starts its part well before its first note.
    test "a part started after it was muted starts muted, each time it is started", %{
      wav: wav,
      at: at
    } do
      :ok = Mxs.mute(:lead, true)
      first = Mxs.start_part(:lead, [])
      :ok = Mxs.play(at + 20_000, [{:note, nil, :saw, 60, [sustain: 1], first}])
      Mxs.render_to(at + 1_000_000)
      :ok = Mxs.stop_fx(first, at + 1_000_000)
      second = Mxs.start_part(:lead, echo: [phase: 0.25])
      :ok = Mxs.play(at + 1_020_000, [{:note, nil, :saw, 64, [sustain: 1], second}])
      Mxs.render_to(at + 2_000_000)
      third = Mxs.start_part(:lead, [])
      :ok = Mxs.play(at + 2_020_000, [{:note, nil, :saw, 67, [sustain: 1], third}])
      Mxs.render_to(at + 3_000_000)

      assert peaks(wav, [{0.0, 3.0}]) == [0.0]
    end
  end

  describe "levels" do
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      wav = Path.join(dir, "levels.wav")
      start_supervised!({Mxs, live: false, record: wav, fade_ms: 0})
      :ok = Mxs.levels(self())
      %{wav: wav, at: System.os_time(:microsecond)}
    end

    test "come twenty times for a second of sound, with each channel's level and the wave, until told to stop",
         %{at: at} do
      :ok = Mxs.play(at, [{:note, nil, :saw, 60, [sustain: 3], nil}])
      Mxs.render_to(at + 1_000_000)
      reports = levels()

      assert length(reports) in 19..21
      assert %{peak: {left, right}, rms: {left_rms, right_rms}} = List.last(reports)
      assert left > 0.05 and right > 0.05
      assert left_rms > 0 and left_rms < left and right_rms > 0 and right_rms < right

      assert %{wave: wave, full_scale: false, parts: parts} = List.last(reports)
      assert length(wave) == 64
      assert Enum.all?(wave, &(&1 >= -1 and &1 <= 1))
      assert_in_delta wave |> Enum.map(&abs/1) |> Enum.max(), (left + right) / 2, 0.02
      assert parts == %{}

      :ok = Mxs.stop_levels(self())
      levels()
      Mxs.render_to(at + 2_000_000)
      refute_receive {:mx_levels, _}, 300
      assert :sys.get_state(Mxs).asked == %{}
    end

    test "say that the output reached full scale with two notes at amp: 4", %{at: at} do
      :ok = Mxs.play(at, [{:note, nil, :saw, 60, [sustain: 1], nil}])
      Mxs.render_to(at + 500_000)
      assert Enum.all?(levels(), &(not &1.full_scale))

      loud = for note <- [48, 60], do: {:note, nil, :saw, note, [sustain: 1, amp: 4], nil}
      :ok = Mxs.play(at + 500_000, loud)
      Mxs.render_to(at + 1_000_000)
      assert Enum.any?(levels(), & &1.full_scale)
    end

    test "give each part's level by its name, lower at amp 0.2 than at 0.9, and 0 for notes at amp: 0",
         %{at: at} do
      flute = Mxs.start_part(:flute, [])
      silent = Mxs.start_part(:silent, [])

      :ok =
        Mxs.play(at, [
          {:note, nil, :saw, 72, [sustain: 1, release: 0.01, amp: 0.9], flute},
          {:note, nil, :saw, 48, [sustain: 2, amp: 0], silent}
        ])

      Mxs.render_to(at + 1_000_000)
      loud = levels()
      :ok = Mxs.play(at + 1_100_000, [{:note, nil, :saw, 72, [sustain: 1, amp: 0.2], flute}])
      Mxs.render_to(at + 2_000_000)
      quiet = levels()

      level = fn reports, part ->
        reports |> Enum.slice(5, 10) |> Enum.map(&elem(&1.parts[part].rms, 0)) |> Enum.max()
      end

      assert level.(loud, "flute") > 0.05
      assert_in_delta level.(quiet, "flute"), level.(loud, "flute") * 0.2 / 0.9, 0.01

      for report <- loud ++ quiet do
        assert report.parts["silent"] == %{peak: {0.0, 0.0}, rms: {0.0, 0.0}}
        assert Map.keys(report.parts) == ["flute", "silent"]
      end
    end

    test "the bands run from 50 Hz to 16 kHz, each octave split alike" do
      bands = Mxs.bands()
      assert length(bands) == 25
      assert_in_delta bands |> hd() |> elem(0), 50, 0.001
      assert_in_delta bands |> List.last() |> elem(1), 16_000, 0.001

      for [{low, high}, {next_low, next_high}] <- Enum.chunk_every(bands, 2, 1, :discard) do
        assert high == next_low
        assert_in_delta next_high / next_low, high / low, 1.0e-9
      end
    end

    test "a sine at a4 is loudest in the band that holds 440 Hz, and 30 dB lower an octave away",
         %{at: at} do
      :ok = Mxs.play(at, [{:note, nil, :fm, 69, [depth: 0, sustain: 2], nil}])
      Mxs.render_to(at + 1_000_000)
      %{bands: levels} = List.last(levels())
      assert length(levels) == 25

      band = fn hz ->
        Enum.find_index(Mxs.bands(), fn {low, high} -> low <= hz and hz < high end)
      end

      loudest = Enum.max(levels)
      assert Enum.at(levels, band.(440)) == loudest
      assert loudest > -40
      assert Enum.at(levels, band.(220)) < loudest - 30
      assert Enum.at(levels, band.(880)) < loudest - 30
    end

    test "silence has every band at -120 dB", %{at: at} do
      Mxs.render_to(at + 500_000)
      assert [_ | _] = reports = levels()
      for report <- reports, do: assert(report.bands == List.duplicate(-120.0, 25))
    end

    test "the loudest level sent is the loudest sample of the recording, within 0.5 dB", %{
      wav: wav,
      at: at
    } do
      for {note, beat} <- Enum.with_index([48, 55, 60, 64, 67]) do
        events = [{:note, nil, :piano, note, [vel: 0.9], nil}]
        :ok = Mxs.play(at + beat * 300_000, events)
      end

      Mxs.render_to(at + 2_500_000)
      sent = levels() |> Enum.flat_map(&Tuple.to_list(&1.peak)) |> Enum.max()
      [recorded] = peaks(wav, [{0.0, 2.5}])

      assert recorded > 0.05
      assert_in_delta 20 * :math.log10(sent / recorded), 0, 0.5
    end
  end

  describe "a live engine" do
    setup do
      start_supervised!(Mxs)
      :ok
    end

    @tag :engine
    test "sends levels about twenty times a second, and none a tenth of a second after it stops" do
      :ok = Mxs.levels(self())
      assert_receive {:mx_levels, _}, 500
      started = System.monotonic_time(:millisecond)
      Process.sleep(2000)
      stop_supervised!(Mxs)
      stopped = System.monotonic_time(:millisecond)
      Process.sleep(100)
      sent = length(levels())

      assert_in_delta sent / (stopped - started) * 1000, 20, 2
      refute_receive {:mx_levels, _}, 300
    end

    @tag :engine
    test "names the output it plays to, with its rate and a delay above 0" do
      assert %{device: device, rate: rate, delay_ms: delay_ms} = Mxs.output(self())
      assert is_binary(device) and device != ""
      assert rate in [44_100.0, 48_000.0, 88_200.0, 96_000.0]
      assert delay_ms > 0
    end

    @tag :engine
    test "sends the notes that sound about once a second while it plays" do
      at = System.os_time(:microsecond)
      notes = for note <- [60, 64, 67], do: {:note, nil, :saw, note, [amp: 0, sustain: 30], nil}
      :ok = Mxs.play(at, notes)
      Process.sleep(300)
      :ok = Mxs.voices(self())

      # The first report comes as soon as it is asked for, and the rest on the engine's whole seconds.
      assert_receive {:mx_voices, 3}, 1500

      times =
        for _ <- 1..3 do
          assert_receive {:mx_voices, count}, 1500
          assert count > 0
          System.monotonic_time(:millisecond)
        end

      [first, second] =
        times |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

      assert_in_delta first, 1000, 300
      assert_in_delta second, 1000, 300
    end
  end

  # Stops the engine, and gives the peak of its recording within each stretch of seconds.
  defp peaks(wav, stretches) do
    stop_supervised!(Mxs)
    {:ok, %{samples: samples, rate: rate}} = Mx.Audio.read(wav)

    for {from, to} <- stretches do
      first = round(from * rate)
      count = round(to * rate) - first
      samples |> Enum.slice(first, count) |> Enum.map(&abs/1) |> Enum.max()
    end
  end

  # The levels sent until none comes for a fifth of a second, the earliest first.
  defp levels do
    receive do
      {:mx_levels, levels} -> [levels | levels()]
    after
      200 -> []
    end
  end

  defp flush_voices do
    receive do
      {:mx_voices, _} -> flush_voices()
    after
      0 -> :ok
    end
  end

  # Wakes every millisecond, and says the longest it was woken late by, in microseconds.
  defp tick(test, last, latest) do
    receive do
      :stop -> send(test, {:latest, latest})
    after
      1 ->
        now = System.monotonic_time(:microsecond)
        tick(test, now, max(latest, now - last - 1000))
    end
  end

  test "renders at the rate an offline engine runs at" do
    {:ok, engine} = Mxs.Native.start(false, false)

    assert Mxs.render_rate() == 48_000
    assert Mxs.Native.rate(engine) == Mxs.render_rate()
  end
end
