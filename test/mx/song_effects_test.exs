defmodule Mx.SongEffectsTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000
  @look_ahead 240

  defp write(ctx, song) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\n" <> song <> "\n")
    path
  end

  # The two sides of a render of a song, and what it printed.
  defp render(ctx, song) do
    path = write(ctx, song)
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    printed = capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    {left, right} = Enum.unzip(frames)
    {left, right, printed}
  end

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()
  defp db(level), do: 20 * :math.log10(level)

  @tag :engine
  test "a limiter on the song keeps a loud note under its ceiling, where the note clips without it",
       ctx do
    note = "part(:x, note(:a2, 2, amp: 4), synth: :saw)"
    {left, right, printed} = render(ctx, "song(tempo: 120, music: #{note})")
    assert max(peak(left), peak(right)) > 1.0
    assert printed =~ "clipped"

    {left, right, printed} =
      render(ctx, "song(tempo: 120, fx: [limiter: [ceiling: -1]], music: #{note})")

    assert db(max(peak(left), peak(right))) <= -1.0 + 1.0e-4
    assert db(peak(left)) > -1.5
    refute printed =~ "clipped"
  end

  @tag :engine
  test "a quiet note through the song's limiter is the dry note, 5 ms late", ctx do
    note = "part(:x, note(:a2, 2, amp: 0.1), synth: :saw)"
    {dry, _, _} = render(ctx, "song(tempo: 120, music: #{note})")
    {wet, _, _} = render(ctx, "song(tempo: 120, fx: [limiter: []], music: #{note})")
    kept = length(dry) - @look_ahead
    assert Enum.take(dry, kept) == wet |> Enum.drop(@look_ahead) |> Enum.take(kept)
  end

  @tag :engine
  test "every part plays through the song's effects after its own", ctx do
    parts =
      "together([part(:a, note(:a2, 1), synth: :saw), part(:b, note(:e4, 1, amp: 0.5), synth: :tri, fx: [level: []])])"

    {dry, _, _} = render(ctx, "song(tempo: 120, music: #{parts})")
    {halved, _, _} = render(ctx, "song(tempo: 120, fx: [level: [amp: 0.5]], music: #{parts})")
    assert peak(dry) > 0.05
    assert peak(Enum.zip_with(dry, halved, &(&1 * 0.5 - &2))) < 1.0e-6

    silent = "seq([#{parts}, rest(2)])"
    {dry, _, _} = render(ctx, "song(tempo: 120, music: #{silent})")
    {wet, _, _} = render(ctx, "song(tempo: 120, fx: [reverb: [mix: 1]], music: #{silent})")
    after_notes = fn samples -> samples |> Enum.drop(round(1.2 * @rate)) |> peak() end
    assert after_notes.(dry) < 1.0e-4
    assert after_notes.(wet) > 0.001
  end

  @tag :engine
  test "a change that names the song reaches one of its effects from where it is written", ctx do
    note = "part(:x, note(:a2, 4, amp: 4), synth: :saw)"
    change = "seq([rest(2), change({:song, :limiter}, ceiling: -6)])"
    song = "song(tempo: 120, fx: [limiter: [ceiling: -1]], music: together([#{note}, #{change}]))"
    {left, _, _} = render(ctx, song)
    first = left |> Enum.slice(round(0.2 * @rate)..(round(0.9 * @rate) - 1)) |> peak()
    second = left |> Enum.slice(round(1.2 * @rate)..(round(1.9 * @rate) - 1)) |> peak()
    assert_in_delta db(first), -1, 0.3
    assert_in_delta db(second), -6, 0.3

    inside =
      "part(:x, seq([note(:a2, 2, amp: 4), change({:song, :limiter}, ceiling: -6), note(:a2, 2, amp: 4)]), synth: :saw)"

    {left, _, _} = render(ctx, "song(tempo: 120, fx: [limiter: [ceiling: -1]], music: #{inside})")
    second = left |> Enum.slice(round(1.2 * @rate)..(round(1.9 * @rate) - 1)) |> peak()
    assert_in_delta db(second), -6, 0.3
  end

  test "a song's fx: and a change to it are checked when the song loads", ctx do
    note = "part(:x, note(:a2, 1), synth: :saw)"
    load = fn song -> Mx.Song.load(write(ctx, song)) end
    path = Path.join(ctx.tmp_dir, "song.exs")

    assert {:ok, %{fx: [limiter: [ceiling: -3], eq: [mid_gain: 2]]}} =
             load.("song(fx: [limiter: [ceiling: -3], eq: [mid: [gain: 2]]], music: #{note})")

    assert {:ok, %{fx: []}} = load.("song(music: #{note})")

    assert load.("song(fx: [limitr: []], music: #{note})") ==
             {:error, "#{path}:2: the song's fx: mx has no effect limitr"}

    assert load.("song(fx: [limiter: [ceiling: 3]], music: #{note})") ==
             {:error,
              "#{path}:2: the song's fx: effect limiter takes ceiling from -60 to 0, not 3"}

    changed = fn change -> "song(fx: [limiter: []], music: together([#{note}, #{change}]))" end

    assert load.(changed.("change({:song, :reverb}, decay_seconds: 12)")) ==
             {:error, "#{path}:2: change names effect reverb, which the song's fx: does not have"}

    assert load.(changed.("change({:song, :limiter}, decay_seconds: 12)")) ==
             {:error, "#{path}:2: effect limiter has no option decay_seconds"}

    assert {:ok, _song} = load.(changed.("change({:song, :limiter}, ceiling: -6)"))
  end

  test "a render's ring-out counts the song's effects after each part's", ctx do
    parts = "part(:x, note(:a2, 1), synth: :saw, fx: [echo: [phase: 0.5, decay: 2]])"
    {:ok, alone} = Mx.Song.load(write(ctx, "song(tempo: 120, music: #{parts})"))

    {:ok, both} =
      Mx.Song.load(
        write(ctx, "song(tempo: 120, fx: [reverb: [decay_seconds: 5.1]], music: #{parts})")
      )

    {:ok, %{seconds: echo, part: :x, effect: :echo}} = Mx.Render.ring_out(alone)
    {:ok, %{seconds: seconds, part: :song, effect: :reverb}} = Mx.Render.ring_out(both)
    assert seconds > echo + 1

    path =
      write(
        ctx,
        "song(tempo: 120, fx: [limiter: []], music: part(:x, note(:a2, 1), synth: :saw))"
      )

    out = Path.join(ctx.tmp_dir, "quiet.wav")
    printed = capture_io(fn -> assert :ok = Mx.Render.render(path, out, []) end)
    refute printed =~ "cutting short"

    assert {:ok, %{seconds: 0.005, part: :song, effect: :limiter}} =
             path |> Mx.Song.load() |> elem(1) |> Mx.Render.ring_out()
  end

  test "a part named song is refused, as the name is the song's own chain", ctx do
    path = write(ctx, "song(music: part(:song, note(:a2, 1), synth: :saw))")

    assert Mx.Song.load(path) ==
             {:error,
              "#{path}:2: a part cannot be named song: the name is taken by the song's own chain, the effects of its fx:"}
  end

  @tag :engine
  test "a module song takes fx: beside its tempo", ctx do
    path = Path.join(ctx.tmp_dir, "module.exs")
    out = Path.join(ctx.tmp_dir, "module.wav")

    File.write!(path, """
    defmodule Mx.SongEffectsTest.Loud do
      use Mx.Song, tempo: 120, fx: [limiter: [ceiling: -3]]

      part :x, synth: :saw

      def song, do: part(:x, note(:a2, 2, amp: 4))
    end
    """)

    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    assert_in_delta Mx.Recording.level(out).peak, -3, 0.3
  after
    :code.purge(Mx.SongEffectsTest.Loud)
    :code.delete(Mx.SongEffectsTest.Loud)
  end
end
