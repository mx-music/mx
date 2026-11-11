defmodule Mx.InstrumentSongTest do
  use ExUnit.Case, async: false

  alias Mx.Engine.Mxs

  @moduletag :tmp_dir

  setup do
    engine = Application.get_env(:mx, :engine)
    modules = Mx.Instrument.modules()
    Application.put_env(:mx, :engine, Rust)

    on_exit(fn ->
      Application.put_env(:mx, :engine, engine)
      :persistent_term.put({Mx.Instrument, :modules}, modules)
      Mx.Synths.forget()
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
    quiet = Rust.render_note(:bell, [note: 72], 1.0, nil, [])
    ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.eval_string(bell(0.4)) end)
    loud = Rust.render_note(:bell, [note: 72], 1.0, nil, [])
    assert_in_delta peak(loud) / peak(quiet), 4.0, 0.01
  end

  test "a song file that defines a defsynth plays it by name", ctx do
    path = Path.join(ctx.tmp_dir, "bells.exs")
    music = "part(:a, loop(1, fn _, _ -> seq([note(72, 0), rest(1)]) end), synth: :bell)"
    File.write!(path, "import Mx\n" <> bell(0.1) <> "song(tempo: 60, music: #{music})\n")
    assert {:ok, _song} = Mx.Song.load(path)
  end
end
