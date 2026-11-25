defmodule Mx.InstrumentSongTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Mx.Engine.Mxs

  @moduletag :tmp_dir

  setup do
    engine = Application.get_env(:mx, :engine)
    modules = Mx.Instrument.modules()
    Application.put_env(:mx, :engine, Rust)
    ignoring = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, false)

    on_exit(fn ->
      Application.put_env(:mx, :engine, engine)
      Code.put_compiler_option(:ignore_module_conflict, ignoring)
      :persistent_term.put({Mx.Instrument, :modules}, modules)
      Mx.Synths.forget()

      for module <- [
            Mx.InstrumentSongTest.Bell,
            Mx.InstrumentSongTest.Quieter,
            Mx.InstrumentSongTest.Pulse,
            Mx.InstrumentSongTest.Tails,
            Mx.InstrumentSongTest.Later,
            Mx.InstrumentSongTest.Zeroed,
            Mx.InstrumentSongTest.Shared,
            Mx.InstrumentSongTest.SongFirst,
            Mx.InstrumentSongTest.InstrumentFirst
          ] do
        :code.purge(module)
        :code.delete(module)
      end
    end)
  end

  defp bell(level) do
    """
    defmodule Mx.InstrumentSongTest.Bell do
      use Mx.Instrument
      attr :note, :note, default: 72

      defsynth bell(hit) do
        impulse() |> mode(hz: hz(hit.note), level: #{level}, fade: 1) |> rings(seconds: 1.5)
      end
    end
    """
  end

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()

  test "a defsynth defined while mx runs is a synth songs can play, and plays its new body when defined again" do
    refute Mx.Synths.exists?(:bell)
    Code.eval_string(bell(0.1))
    assert Mx.Synths.exists?(:bell)
    quiet = Mxs.render_note(:bell, [note: 72], 1.0, nil, [])
    output = capture_io(:stderr, fn -> Code.eval_string(bell(0.4)) end)
    assert output =~ "redefining module Mx.InstrumentSongTest.Bell"
    loud = Mxs.render_note(:bell, [note: 72], 1.0, nil, [])
    assert_in_delta peak(loud) / peak(quiet), 4.0, 0.01
  end

  test "a song file that defines a defsynth plays it by name", ctx do
    path = Path.join(ctx.tmp_dir, "bells.exs")
    music = "part(:a, loop(1, fn _, _ -> seq([note(72, 0), rest(1)]) end), synth: :bell)"
    File.write!(path, "import Mx\n" <> bell(0.1) <> "song(tempo: 60, music: #{music})\n")
    assert {:ok, _song} = Mx.Song.load(path)
  end

  @quieter """
  defmodule Mx.InstrumentSongTest.Quieter do
    use Mx.Instrument

    attr :level, :float, default: 0.5, range: 0..1, doc: "How loud the sound comes out."
    defeffect quieter(sound, opts), do: sound |> gain(opts.level)
  end
  """

  test "a defeffect defined while mx runs is an effect songs apply by name" do
    Code.eval_string(bell(0.1))
    Code.eval_string(@quieter)
    assert Mx.Synths.effect?(:quieter)
    dry = Mxs.render_note(:bell, [note: 72], 1.0, nil, [])
    {left, right} = Mxs.render_through(:bell, [note: 72], 1.0, nil, quieter: [level: 0.25])
    assert_in_delta peak(left) / peak(dry), 0.25, 0.001
    assert_in_delta peak(right) / peak(dry), 0.25, 0.001
  end

  test "a song file that defines a defeffect applies it with fx", ctx do
    path = Path.join(ctx.tmp_dir, "quiet_bells.exs")

    music =
      "part(:a, loop(1, fn _, _ -> seq([note(72, 0), rest(1)]) end), synth: :bell, fx: [quieter: [level: 0.5]])"

    File.write!(
      path,
      "import Mx\n" <> bell(0.1) <> @quieter <> "song(tempo: 60, music: #{music})\n"
    )

    assert {:ok, _song} = Mx.Song.load(path)
  end

  test "a song file that defines a defeffect renders through it", ctx do
    render = fn name, fx ->
      path = Path.join(ctx.tmp_dir, name <> ".exs")
      out = Path.join(ctx.tmp_dir, name <> ".wav")
      music = "part(:x, note(:c4, 2), synth: :saw#{fx})"
      File.write!(path, "import Mx\n" <> @quieter <> "song(tempo: 120, music: #{music})\n")
      capture_io(fn -> refute match?({:error, _}, Mx.Render.render(path, out, [])) end)
      Mx.Recording.level(out).peak
    end

    dry = render.("dry", "")
    assert_in_delta render.("half", ", fx: [quieter: []]"), dry - 6.02, 0.1
    assert_in_delta render.("quarter", ", fx: [quieter: [level: 0.25]]"), dry - 12.04, 0.1

    {:ok, song} = Mx.Song.load(Path.join(ctx.tmp_dir, "half.exs"))
    assert Mx.Render.ring_out(song) == {:ok, %{seconds: 1.0, part: :x, effect: :quieter}}
  end

  @tails """
  defmodule Mx.InstrumentSongTest.Tails do
    use Mx.Instrument

    defeffect late(sound, _opts), do: sound |> delay(seconds: 2.5, max: 3)

    tail 3.0
    defeffect late_ringing(sound, _opts), do: sound |> delay(seconds: 2.5, max: 3)

    attr :decay, :beats, default: 4
    tail :decay
    defeffect decaying(sound, opts), do: sound |> gain(opts.decay / opts.decay)
  end
  """

  test "a defeffect's tail says how long a render keeps it sounding after the last note", ctx do
    render = fn fx ->
      path = Path.join(ctx.tmp_dir, "tail.exs")
      out = Path.join(ctx.tmp_dir, "tail.wav")
      music = "part(:x, note(:c4, 0.2, release: 0.01), synth: :saw, fx: [#{fx}: []])"
      File.write!(path, @tails <> "import Mx\nsong(tempo: 120, music: #{music})\n")
      File.rm(out)

      capture_io(fn ->
        refute match?({:error, _}, Mx.Render.render(path, out, ring_out: true))
      end)

      {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(out)

      {length(samples) / rate,
       samples |> Enum.drop(2 * rate) |> Enum.map(&abs/1) |> Enum.max(fn -> 0.0 end)}
    end

    assert {seconds, late} = render.("late_ringing")
    assert_in_delta seconds, 3.1, 0.2
    assert late > 0.01

    assert {seconds, late} = render.("late")
    assert_in_delta seconds, 1.1, 0.2
    assert late == 0.0
  end

  test "a defeffect's tail named after an option in beats lasts those beats at the song's tempo",
       ctx do
    load = fn fx ->
      path = Path.join(ctx.tmp_dir, "decaying.exs")
      music = "part(:x, note(:c4, 1), synth: :saw, fx: [#{fx}])"
      File.write!(path, @tails <> "import Mx\nsong(tempo: 120, music: #{music})\n")
      {:ok, song} = Mx.Song.load(path)
      song
    end

    assert Mx.Render.ring_out(load.("decaying: []")) ==
             {:ok, %{seconds: 2.0, part: :x, effect: :decaying}}

    assert Mx.Render.ring_out(load.("decaying: [decay: 2]")) ==
             {:ok, %{seconds: 1.0, part: :x, effect: :decaying}}
  end

  @later """
  defmodule Mx.InstrumentSongTest.Later do
    use Mx.Instrument

    defeffect later(sound, _opts), do: sound |> delay(seconds: 0.1, max: 1)

    attr :note, :note, default: 69
    envelope_attrs sustain: 0.2, release: 0.01
    defsynth held_back(o), do: clamp(delay(sine(hz: hz(o.note)), seconds: 0.1, max: 1), -1, 1) |> note_envelope(o)
  end
  """

  # Where a render of music first sounds, in seconds.
  defp starts(ctx, source, music) do
    path = Path.join(ctx.tmp_dir, "later.exs")
    out = Path.join(ctx.tmp_dir, "later.wav")
    File.write!(path, source <> "song(tempo: 120, music: #{music})\n")
    File.rm(out)
    capture_io(fn -> refute match?({:error, _}, Mx.Render.render(path, out, [])) end)
    {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(out)
    Enum.find_index(samples, &(abs(&1) > 1.0e-4)) / rate
  end

  test "a song file that imports Mx at its top defines an effect and a synth that call the delay node",
       ctx do
    source = "import Mx\n" <> @later
    assert_in_delta starts(ctx, source, "part(:x, note(:c4, 1), synth: :saw)"), 0.0, 0.01

    assert_in_delta starts(ctx, source, "part(:x, note(:c4, 1), synth: :saw, fx: [later: []])"),
                    0.1,
                    0.01

    assert_in_delta starts(ctx, source, "part(:x, note(:c4, 1), synth: :held_back)"), 0.1, 0.01

    assert_in_delta starts(ctx, source, "part(:x, delay(note(:c4, 1), 2), synth: :saw)"),
                    1.0,
                    0.01
  end

  test "every name Mx and the nodes share is the node inside a defeffect below import Mx" do
    nodes = MapSet.new(Mx.Instrument.Vocabulary.__info__(:functions))
    functions = Mx.__info__(:functions)
    shared = functions |> Enum.filter(&(&1 in nodes)) |> Enum.sort()
    assert shared == [clamp: 3, delay: 2]

    source = """
    import Mx

    defmodule Mx.InstrumentSongTest.Shared do
      use Mx.Instrument
      defeffect shared(sound, _opts), do: clamp(delay(sound, seconds: 0.1, max: 1), -1, 1)
    end
    """

    # Mx's clamp and delay go unused, as the nodes take their names inside the defeffect.
    warnings =
      capture_io(:stderr, fn ->
        assert [{Mx.InstrumentSongTest.Shared, _}] = Code.compile_string(source, "shared.exs")
      end)

    assert warnings =~ "unused import Mx"
  end

  test "a module that uses Mx.Song and Mx.Instrument, in either order, has the delay node in an effect and Mx's delay in its music",
       ctx do
    for {name, uses} <- [
          {"SongFirst", "use Mx.Song, tempo: 120\n  use Mx.Instrument"},
          {"InstrumentFirst", "use Mx.Instrument\n  use Mx.Song, tempo: 120"}
        ] do
      source = """
      defmodule Mx.InstrumentSongTest.#{name} do
        #{uses}

        defeffect later_too(sound, _opts), do: sound |> delay(seconds: 0.1, max: 1)

        part :x, synth: :saw, fx: [later_too: []]

        def song, do: part(:x, delay(note(:c4, 1), 2))
      end
      """

      path = Path.join(ctx.tmp_dir, name <> ".exs")
      out = Path.join(ctx.tmp_dir, name <> ".wav")
      File.write!(path, source)
      capture_io(fn -> refute match?({:error, _}, Mx.Render.render(path, out, [])) end)
      {:ok, %{rate: rate, samples: samples}} = Mx.Audio.read(out)
      assert_in_delta Enum.find_index(samples, &(abs(&1) > 1.0e-4)) / rate, 1.1, 0.01
    end
  end

  @zeroed """
  defmodule Mx.InstrumentSongTest.Zeroed do
    use Mx.Instrument

    defeffect silenced(sound, _opts), do: sound * 0 + sound

    attr :wet, :float, default: 0
    defeffect wetter(sound, opts), do: sound * opts.wet + sound

    attr :on, :float, default: 1
    defeffect picked(sound, opts), do: select(opts.on, sound, sound * 0.5)

    defeffect right_on_both({left, right}, _opts), do: {left * 0 + right, right}

    defeffect broken(sound, _opts), do: sound |> delay(seconds: 0.1, max: sound)
  end
  """

  # The two sides of a saw note through effects written in a song file, or the error its render
  # gives.
  defp zeroed(ctx, fx) do
    path = Path.join(ctx.tmp_dir, "zeroed.exs")
    out = Path.join(ctx.tmp_dir, "zeroed.wav")
    music = "part(:x, note(:c4, 1), synth: :saw, fx: #{fx})"
    File.write!(path, @zeroed <> "import Mx\nsong(tempo: 120, music: #{music})\n")
    File.rm(out)
    parent = self()

    capture_io(:stderr, fn ->
      capture_io(fn -> send(parent, {:rendered, Mx.Render.render(path, out, [])}) end)
    end)

    receive do
      {:rendered, :ok} ->
        {:ok, _format, data} = Mx.Audio.raw(out)
        frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
        Enum.unzip(frames)

      {:rendered, error} ->
        error
    end
  end

  test "an effect whose input is multiplied by 0 or left out of a select plays the rest", ctx do
    {dry, _} = zeroed(ctx, "[level: []]")
    assert peak(dry) > 0.01

    {left, _} = zeroed(ctx, "[silenced: []]")
    assert peak(Enum.zip_with(left, dry, &(&1 - &2))) <= peak(dry) * 1.0e-5

    {left, _} = zeroed(ctx, "[wetter: []]")
    assert peak(Enum.zip_with(left, dry, &(&1 - &2))) <= peak(dry) * 1.0e-5
    {left, _} = zeroed(ctx, "[wetter: [wet: 1]]")
    assert_in_delta peak(left), 2 * peak(dry), 1.0e-4

    {left, _} = zeroed(ctx, "[picked: []]")
    assert_in_delta peak(left), peak(dry), 1.0e-5
    {left, _} = zeroed(ctx, "[picked: [on: 0]]")
    assert_in_delta peak(left), 0.5 * peak(dry), 1.0e-5

    {left, right} = zeroed(ctx, "[pan: [pan: 1], right_on_both: []]")
    assert peak(right) > 0.01
    assert left == right
  end

  test "an effect that cannot be built ends the render with an error naming the part and the effect",
       ctx do
    {{micros, result}, log} =
      with_log(fn -> :timer.tc(fn -> zeroed(ctx, "[broken: []]") end) end)

    assert log =~
             "effect broken could not be built: a delay's max must be known when the note starts"

    assert result ==
             {:error,
              "part x: effect broken could not be built: a delay's max must be known when the note starts"}

    assert micros < 1_000_000
  end

  test "a defeffect's option given a value outside the range its attr declares is refused when the song loads",
       ctx do
    path = Path.join(ctx.tmp_dir, "loud_bells.exs")
    music = "part(:a, note(72, 1), synth: :bell, fx: [quieter: [level: 2]])"

    File.write!(
      path,
      "import Mx\n" <> bell(0.1) <> @quieter <> "song(tempo: 60, music: #{music})\n"
    )

    assert {:error, message} = Mx.Song.load(path)
    assert message =~ "part a: effect quieter takes level from 0 to 1, not 2"
  end

  test "a defeffect declares an option in milliseconds as it declares one in beats" do
    {{:module, late, _binary, _last}, _binding} =
      Code.eval_string("""
      defmodule Mx.InstrumentSongTest.Late do
        use Mx.Instrument
        attr :gap_ms, :ms, default: 20, range: 0..100

        defeffect late(sound, opts), do: sound |> delay(seconds: opts.gap_ms / 1000)
      end
      """)

    assert %{kind: "ms", default: 20.0} =
             Enum.find(
               Mx.Instrument.specs(hd(late.__effects__())),
               &(&1.name == "gap_ms")
             )

    assert Mx.Synths.check_value({:effect, :late}, :gap_ms, 200) ==
             {:error, "effect late takes gap_ms from 0 to 100, not 200"}
  end

  test "a defeffect that ends a note fails when its module compiles" do
    source = """
    defmodule Mx.InstrumentSongTest.Ringing do
      use Mx.Instrument
      defeffect ringing(sound, _opts), do: sound |> rings(seconds: 1)
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "ringing.exs") end
    assert error.line == 3
    assert Exception.message(error) =~ "returns its sound"
  end

  test "an option a defsynth declares in beats is given in beats and played in seconds" do
    Code.eval_string("""
    defmodule Mx.InstrumentSongTest.Pulse do
      use Mx.Instrument
      attr :note, :note, default: 60
      attr :gap, :beats, default: 1
      attr :level, :float, default: 1
      envelope_attrs()

      defsynth pulse(hit) do
        sine(hz: hz(hit.note)) |> gain(hit.level * hit.gap) |> note_envelope(hit)
      end
    end
    """)

    assert Mx.Synths.to_seconds(:pulse, [gap: 2, level: 2], 120)[:gap] == 1.0
    assert Mx.Synths.to_seconds(:pulse, [gap: 2, level: 2], 120)[:level] == 2
    assert Mx.Synths.to_seconds(:pulse, [], 120)[:gap] == 0.5
  end
end
