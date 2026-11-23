defmodule Mx.WahTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000

  # The left side of a render at 120 bpm of a part of saws through the effects given.
  defp render(ctx, notes, fx) do
    music = "part(:clav, #{notes}, synth: :saw, fx: #{fx})"
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\nsong(tempo: 120, music: #{music})\n")
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: true) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    for <<left::little-float-32, _right::little-float-32 <- data>>, do: left
  end

  # The level in dB of the part of the sound at a frequency, over the seconds given from a time,
  # under a Hann window.
  defp part_at(samples, hz, from, seconds) do
    count = round(seconds * @rate)
    turn = 2 * :math.pi() * hz / @rate

    {re, im} =
      samples
      |> Enum.slice(round(from * @rate), count)
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {sample, index}, {re, im} ->
        window = 0.5 - 0.5 * :math.cos(2 * :math.pi() * index / count)

        {re + window * sample * :math.cos(turn * index),
         im + window * sample * :math.sin(turn * index)}
      end)

    10 * :math.log10(max(re * re + im * im, 1.0e-30))
  end

  # A2 for a beat, half a second, which then fades over two seconds; its 18th harmonic is at
  # 1980 Hz.
  defp struck(vel), do: "note(:a2, 1, attack: 0, release: 4, vel: #{vel})"

  @open "cutoff_min: 60, cutoff_max: 100"

  # How far the note's harmonic at 1980 Hz is over its first, in its first 0.05 seconds and from
  # half a second after it is released.
  defp brightness(sound) do
    for from <- [0.0, 1.0] do
      part_at(sound, 1980, from, 0.05) - part_at(sound, 110, from, 0.05)
    end
  end

  @tag :engine
  test "a note opens the filter as it starts and the filter closes as the note fades", ctx do
    sound = render(ctx, struck(1), "[wah: [#{@open}]]")
    assert part_at(sound, 1980, 0, 0.05) >= part_at(sound, 1980, 1, 0.05) + 12
    [start, faded] = brightness(sound)
    assert start >= faded + 12
  end

  @tag :engine
  test "a note at vel 0.3 opens the filter less than one at vel 1", ctx do
    start = fn vel, fx -> part_at(render(ctx, struck(vel), fx), 1980, 0, 0.05) end
    wet = start.(1, "[wah: [#{@open}]]") - start.(0.3, "[wah: [#{@open}]]")
    dry = start.(1, "[]") - start.(0.3, "[]")
    assert wet >= dry + 6
  end

  # A loud note for half a second over a quiet one at 1975.5 Hz, which shows where the filter is.
  @tag :engine
  test "relax_ms: 500 closes the filter at least twice as slowly as relax_ms: 100", ctx do
    notes =
      "together([note(:a2, 1, attack: 0, release: 0.01), " <>
        "note(95, 5, attack: 0, vel: 0.01)])"

    # The seconds after the loud note ends at which the quiet one is 12 dB under where it was.
    falls = fn relax ->
      sound = render(ctx, notes, "[wah: [#{@open}, relax_ms: #{relax}]]")
      start = part_at(sound, 1975.533, 0.52, 0.02)

      0..140
      |> Enum.map(&(0.52 + &1 * 0.01))
      |> Enum.find(&(part_at(sound, 1975.533, &1, 0.02) <= start - 12))
      |> Kernel.-(0.5)
    end

    assert falls.(500) >= 2 * falls.(100)
  end

  @tag :engine
  test "cutoff_min: 100 with cutoff_max: 60 is duller as the note starts than after it fades",
       ctx do
    [start, faded] =
      brightness(render(ctx, struck(1), "[wah: [cutoff_min: 100, cutoff_max: 60]]"))

    assert start <= faded - 6
  end

  # The frequency at which the filter rings: the harmonic of a held A1 it raises most over dry.
  defp rings_at(ctx, vel, more) do
    held = "note(:a1, 4, attack: 0, vel: #{vel})"
    dry = render(ctx, held, "[]")
    wet = render(ctx, held, "[wah: [#{@open}#{more}]]")

    harmonics = for harmonic <- 2..120, do: harmonic * 55.0
    Enum.max_by(harmonics, &(part_at(wet, &1, 0.5, 1) - part_at(dry, &1, 0.5, 1)))
  end

  @tag :engine
  test "sensitivity: 12 opens the filter on a note at vel 0.3 as far as vel 1 does without",
       ctx do
    loud = rings_at(ctx, 1, "")
    raised = rings_at(ctx, 0.3, ", sensitivity: 12")
    quiet = rings_at(ctx, 0.3, "")
    assert abs(12 * :math.log2(raised / loud)) <= 2
    assert 12 * :math.log2(loud / quiet) > 4
  end

  @tag :engine
  test "wah: [mix: 0] differs from the dry saw by no more than 100 dB below its peak", ctx do
    dry = render(ctx, struck(1), "[]")
    wet = render(ctx, struck(1), "[wah: [mix: 0]]")
    peak = dry |> Enum.map(&abs/1) |> Enum.max()
    assert peak > 0.01
    furthest = wet |> Enum.zip_with(dry, &abs(&1 - &2)) |> Enum.max()
    assert furthest <= peak * 1.0e-5
  end

  test "the guide lists wah and its options" do
    guide = File.read!("documentation/instruments.md")
    [line] = Regex.run(~r/^- `wah` .*$/m, guide)

    for option <- ~w(cutoff_min cutoff_max res sensitivity clamp_ms relax_ms) do
      assert line =~ "`#{option}`"
    end
  end
end
