defmodule Mx.ReverbTest do
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

  # Both sides of a render of a part with the notes and the effects given, for the seconds given.
  defp render(ctx, notes, fx, opts) do
    path =
      write(ctx, "song(tempo: 60, music: part(:x, #{notes}, synth: :closed_hihat, fx: #{fx}))")

    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, opts) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    Enum.unzip(frames)
  end

  defp hit(ctx, fx, seconds \\ 3) do
    render(ctx, "seq([note(60, 0), rest(#{seconds})])", fx, ring_out: false)
  end

  defp between(samples, from, to) do
    Enum.slice(samples, round(from * @rate)..(round(to * @rate) - 1))
  end

  defp rms(samples), do: :math.sqrt(Enum.sum_by(samples, &(&1 * &1)) / length(samples))
  defp db(level), do: 20 * :math.log10(max(level, 1.0e-12))

  defp first_sound(samples) do
    peak = samples |> Enum.map(&abs/1) |> Enum.max()
    floor = peak / 1000
    Enum.find_index(samples, &(abs(&1) > floor))
  end

  # The level in dB around a frequency, as the mean of the power at frequencies 2 Hz apart.
  defp level_around(samples, hz) do
    powers =
      for near <- [hz - 6, hz - 4, hz - 2, hz, hz + 2, hz + 4, hz + 6] do
        step = 2 * :math.pi() * near / @rate

        {re, im, _} =
          Enum.reduce(samples, {0.0, 0.0, 0}, fn x, {re, im, n} ->
            {re + x * :math.cos(step * n), im + x * :math.sin(step * n), n + 1}
          end)

        re * re + im * im
      end

    10 * :math.log10(Enum.sum(powers) / length(powers))
  end

  @tag :engine
  test "the reverb of a sound on the left is louder on the left", ctx do
    notes = "note(60, 1, pan: -1)"
    {left, right} = render(ctx, notes, "[reverb: [mix: 1]]", ring_out: true)
    assert db(rms(left)) >= db(rms(right)) + 3
    assert db(rms(right)) > db(rms(left)) - 20
  end

  @tag :engine
  test "the reverb fades 60 dB in its decay_seconds", ctx do
    {left, _} = hit(ctx, "[reverb: [decay_seconds: 2, mix: 1]]")
    level = fn at -> db(rms(between(left, at, at + 0.1))) end
    fallen = level.(0.5) - level.(1.5)
    assert fallen > 60 / 2.4 and fallen < 60 / 1.6

    {left, _} = hit(ctx, "[reverb: [decay_seconds: 6, mix: 1]]")
    level = fn at -> db(rms(between(left, at, at + 0.1))) end
    assert level.(0.5) - level.(1.5) < 15
  end

  @tag :engine
  test "the reverb starts after its predelay_ms, and later in a larger room", ctx do
    {plain, _} = hit(ctx, "[reverb: [mix: 1]]", 1)
    {late, _} = hit(ctx, "[reverb: [predelay_ms: 50, mix: 1]]", 1)
    assert Enum.all?(between(late, 0, 0.05), &(&1 == 0.0))
    assert first_sound(late) == first_sound(plain) + round(0.05 * @rate)

    {small, _} = hit(ctx, "[reverb: [size: 15, mix: 1]]", 1)
    {large, _} = hit(ctx, "[reverb: [size: 40, mix: 1]]", 1)
    assert first_sound(large) > first_sound(small) + round(0.01 * @rate)
  end

  @tag :engine
  test "the reverb's low_cut cuts the room below its note", ctx do
    noise = fn fx ->
      path = write(ctx, "song(tempo: 60, music: part(:x, note(60, 2), synth: :noise, fx: #{fx}))")
      out = Path.join(ctx.tmp_dir, "noise.wav")
      File.rm(out)
      capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
      {:ok, _format, data} = Mx.Audio.raw(out)
      for <<left::little-float-32, _right::little-float-32 <- data>>, do: left
    end

    open = between(noise.("[reverb: [mix: 1]]"), 0.5, 2)
    cut = between(noise.("[reverb: [low_cut: 60, mix: 1]]"), 0.5, 2)
    assert level_around(cut, 65) <= level_around(open, 65) - 12
    assert_in_delta level_around(cut, 2000), level_around(open, 2000), 2
  end

  @tag :engine
  test "a render with ring_out lasts the reverb's decay_seconds past the last note", ctx do
    {dry, _} = render(ctx, "note(60, 1)", "[]", ring_out: true)
    {wet, _} = render(ctx, "note(60, 1)", "[reverb: [decay_seconds: 3]]", ring_out: true)
    assert_in_delta (length(wet) - length(dry)) / @rate, 3, 0.01
  end

  test "the reverb slides its decay_seconds, low_cut and damp, and neither hall nor room is known",
       ctx do
    load = fn fx ->
      Mx.Song.load(write(ctx, "song(music: part(:x, note(60, 1), synth: :tri, fx: #{fx}))"))
    end

    slid =
      "[reverb: [size: 30, predelay_ms: 20, decay_seconds_slide: 1, low_cut_slide: 1, damp_slide: 1]]"

    assert {:ok, _song} = load.(slid)
    path = Path.join(ctx.tmp_dir, "song.exs")
    assert load.("[hall: []]") == {:error, "#{path}:2: part x: mx has no effect hall"}
    assert load.("[no_such: []]") == {:error, "#{path}:2: part x: mx has no effect no_such"}

    assert load.("[reverb: [room: 0.6]]") ==
             {:error, "#{path}:2: part x: effect reverb has no option room"}

    assert load.("[reverb: [no_such: 1]]") ==
             {:error, "#{path}:2: part x: effect reverb has no option no_such"}
  end

  test "no example or guide gives a reverb a room" do
    for path <- Path.wildcard("{examples,documentation}/**/*.{exs,md,cheatmd}"),
        {line, number} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
        line =~ ~r/\broom: \d|room_slide:/ and not (line =~ "send:") do
      flunk("#{path}:#{number} gives a room: #{line}")
    end

    refute File.exists?("examples/effects/hall.exs")
  end
end
