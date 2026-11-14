defmodule Mx.InstrumentSongTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

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
            Mx.InstrumentSongTest.Pulse
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
