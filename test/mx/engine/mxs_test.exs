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
