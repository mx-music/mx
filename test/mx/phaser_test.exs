defmodule Mx.PhaserTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000

  defp write(ctx, song) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\n" <> song <> "\n")
    path
  end

  # Both sides of a render at 120 bpm of the music given.
  defp render(ctx, music) do
    path = write(ctx, "song(tempo: 120, music: #{music})")
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    Enum.unzip(frames)
  end

  # A sine at a frequency for the beats given, through the effects given.
  defp sine(hz, beats, fx) do
    note = 69 + 12 * :math.log2(hz / 440)
    "part(:x, note(#{note}, #{beats}, depth: 0, attack: 0), synth: :fm, fx: #{fx})"
  end

  defp between(samples, from, to) do
    Enum.slice(samples, round(from * @rate)..(round(to * @rate) - 1))
  end

  defp rms(samples), do: :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / length(samples))
  defp db(level), do: 20 * :math.log10(max(level, 1.0e-12))

  # How far in dB a sine at each frequency comes out of the effects below the same sine dry, on
  # the left.
  defp gains(ctx, hz, fx) do
    for hz <- hz do
      {dry, _} = render(ctx, sine(hz, 2, "[]"))
      {wet, _} = render(ctx, sine(hz, 2, fx))
      db(rms(between(wet, 0.5, 1))) - db(rms(between(dry, 0.5, 1)))
    end
  end

  # The notches of a phaser held at the note 72: where its stages turn the sound an odd number of
  # half cycles.
  defp notches(stages) do
    corner = 440 * :math.pow(2, 3 / 12)

    for notch <- 0..(div(stages, 2) - 1),
        do: corner * :math.tan(:math.pi() * (2 * notch + 1) / (2 * stages))
  end

  defp held(stages, more \\ "") do
    "[phaser: [stages: #{stages}, low: 72, high: 72, mix: 0.5#{more}]]"
  end

  # The level of the left and of the right every 10 ms, from 0.5 seconds on.
  defp levels(ctx, fx) do
    {left, right} = render(ctx, sine(1000, 4, fx))

    every = fn samples ->
      for step <- 0..119, do: rms(between(samples, 0.5 + step / 100, 0.51 + step / 100))
    end

    {every.(left), every.(right)}
  end

  # How far apart two runs of levels are, as a share of how far the first moves.
  defp apart(first, second) do
    mean = Enum.sum(first) / length(first)
    moves = Enum.sum(Enum.map(first, &abs(&1 - mean)))
    Enum.sum(Enum.zip_with(first, second, &abs(&1 - &2))) / moves
  end

  @tag :engine
  test "a phaser of 4 stages cuts 2 notches at least 12 dB deep, and one of 8 stages 4", ctx do
    for stages <- [4, 8] do
      at = notches(stages)
      assert length(at) == div(stages, 2)
      for gain <- gains(ctx, at, held(stages)), do: assert(gain <= -12)
    end

    corner = 440 * :math.pow(2, 3 / 12)
    assert [gain] = gains(ctx, [corner], held(4))
    assert_in_delta gain, 0, 0.5
  end

  @tag :engine
  test "feedback leaves the notches at least 6 dB deeper under the sound between them", ctx do
    corner = 440 * :math.pow(2, 3 / 12)
    [low, _high] = notches(4)
    depth = fn fx -> with [notch, peak] <- gains(ctx, [low, corner], fx), do: peak - notch end
    assert depth.(held(4, ", feedback: 0.7")) >= depth.(held(4)) + 6
  end

  @tag :engine
  test "with phase: 1 at 120 bpm the notches come back every half second, alike on both sides",
       ctx do
    {left, right} = levels(ctx, "[phaser: [phase: 1, low: 60, high: 84, mix: 0.5]]")
    assert Enum.min(left) < Enum.max(left) / 4
    assert apart(Enum.slice(left, 0, 50), Enum.slice(left, 50, 50)) < 0.1
    assert apart(Enum.slice(left, 0, 50), Enum.slice(left, 25, 50)) > 0.5
    assert apart(left, right) < 0.05
  end

  @tag :engine
  test "with stereo_invert_wave: 1 the left is half a sweep away from the right", ctx do
    fx = "[phaser: [phase: 1, low: 60, high: 84, mix: 0.5, stereo_invert_wave: 1]]"
    {left, right} = levels(ctx, fx)
    assert apart(Enum.slice(left, 0, 50), Enum.slice(right, 0, 50)) > 0.5
    assert apart(Enum.slice(left, 0, 50), Enum.slice(right, 25, 50)) < 0.1
  end

  @tag :engine
  test "a phaser given no mix is half dry, so it cuts its notches", ctx do
    for gain <- gains(ctx, notches(4), "[phaser: [low: 72, high: 72]]"), do: assert(gain <= -12)
  end

  test "the phaser's own mix of 0.5 replaces the mix of 1 every effect has" do
    catalog = Mx.Engine.Mxs.catalog()
    assert catalog["fx_phaser"]["mix"] == 0.5
    assert catalog["fx_echo"]["mix"] == 1.0
  end

  @tag :engine
  test "a saw through a phaser with mix: 0 is the dry saw", ctx do
    saw = fn fx -> "part(:x, note(:a3, 2), synth: :saw, fx: #{fx})" end
    {dry, _} = render(ctx, saw.("[]"))
    {off, _} = render(ctx, saw.("[phaser: [mix: 0]]"))
    peak = dry |> Enum.map(&abs/1) |> Enum.max()
    furthest = Enum.zip_with(dry, off, &abs(&1 - &2)) |> Enum.max()
    assert db(furthest) <= db(peak) - 100
  end

  @tag :engine
  test "a change of the phaser's mix with mix_slide: 8 moves it over eight beats", ctx do
    [low, _high] = notches(4)
    note = 69 + 12 * :math.log2(low / 440)
    fx = "[phaser: [stages: 4, low: 72, high: 72, mix: 0]]"
    tone = "note(#{note}, 12, depth: 0, attack: 0)"
    moved = "change({:hihat, :phaser}, mix: 0.75, mix_slide: 8)"
    {left, _} = render(ctx, "part(:hihat, together([#{tone}, #{moved}]), synth: :fm, fx: #{fx})")
    level = fn beat -> db(rms(between(left, beat / 2, beat / 2 + 0.1))) end
    start = level.(0)

    # At this notch the dry sound and the phaser's cancel at mix: 0.5, which the slide passes two
    # thirds of the way.
    assert_in_delta level.(2) - start, db(0.625), 1.5
    assert level.(5.2) - start < -12
    assert_in_delta level.(8.5) - start, db(0.5), 1
    assert_in_delta level.(11) - start, db(0.5), 1
  end

  test "a phaser with stages: 3 is refused when the song loads, naming phaser and stages", ctx do
    path = Path.join(ctx.tmp_dir, "song.exs")

    load = fn options ->
      Mx.Song.load(
        write(ctx, "song(music: part(:x, note(60, 1), synth: :saw, fx: [phaser: [#{options}]]))")
      )
    end

    for stages <- [3, 10, 0, 4.5] do
      assert load.("stages: #{stages}") ==
               {:error,
                "#{path}:2: part x: effect phaser takes stages: as 2, 4, 6 or 8, not #{stages}"}
    end

    for stages <- [2, 4, 6, 8], do: assert({:ok, _song} = load.("stages: #{stages}"))

    assert {:ok, _song} =
             load.(
               "phase_slide: 1, low_slide: 1, high_slide: 1, feedback_slide: 1, wave: 2, invert_wave: 1, phase_offset: 0.5"
             )
  end
end
