defmodule Mx.EffectChangesTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :engine
  @moduletag :tmp_dir
  @rate 48_000

  # The two sides of a saw note of four beats, two seconds, through an effect, with a change to it
  # at the third beat when given.
  defp render(ctx, fx, change) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    out = Path.join(ctx.tmp_dir, "song.wav")
    note = "part(:x, note(:a2, 4, release: 0.01), synth: :saw, fx: #{fx})"
    music = if change, do: "together([#{note}, seq([rest(2), #{change}])])", else: note
    File.write!(path, "import Mx\nsong(tempo: 120, music: #{music})\n")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    Enum.unzip(frames)
  end

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()

  # The largest difference between two renders from one second to another.
  defp apart(first, second, from, to) do
    range = round(from * @rate)..(round(to * @rate) - 1)
    peak(Enum.zip_with(Enum.slice(first, range), Enum.slice(second, range), &(&1 - &2)))
  end

  for {effect, given, option, value} <- [
        {:slicer, "", :smooth_ms, 100},
        {:slicer, "", :phase_offset, 0.5},
        {:tremolo, "phase: 1, depth: 1", :phase_offset, 0.5},
        {:flanger, "feedback: 0.7, phase: 1", :invert_flange, 1},
        {:flanger, "feedback: 0.7, phase: 1", :stereo_invert_wave, 1},
        {:wobble, "", :filter, 1},
        {:ping_pong, "", :pan_start, -1}
      ] do
    @effect effect
    @given given
    @option option
    @value value

    test "a change to #{effect}'s #{option} is heard from where it is written", ctx do
      fx = "[#{@effect}: [#{@given}]]"
      {plain, plain_right} = render(ctx, fx, nil)
      {left, right} = render(ctx, fx, "change({:x, :#{@effect}}, #{@option}: #{@value})")

      assert apart(plain, left, 0, 1) == 0.0 and apart(plain_right, right, 0, 1) == 0.0

      assert max(apart(plain, left, 1.1, 2), apart(plain_right, right, 1.1, 2)) >
               max(peak(plain), peak(plain_right)) / 10
    end
  end

  test "a change to flanger's stereo_invert_wave makes its two sides differ, where they were the same",
       ctx do
    change = "change({:x, :flanger}, stereo_invert_wave: 1)"
    {left, right} = render(ctx, "[flanger: [feedback: 0.7, phase: 1]]", change)
    assert apart(left, right, 0, 1) == 0.0
    assert apart(left, right, 1.1, 2) > peak(left) / 10
  end

  test "a change to a switch does not click", ctx do
    for {fx, change} <- [
          {"[flanger: [feedback: 0.7, phase: 1]]", "change({:x, :flanger}, invert_flange: 1)"},
          {"[flanger: [feedback: 0.7, phase: 1]]",
           "change({:x, :flanger}, stereo_invert_wave: 1)"},
          {"[wobble: []]", "change({:x, :wobble}, filter: 1)"}
        ] do
      {left, right} = render(ctx, fx, change)

      for side <- [left, right] do
        before = side |> Enum.slice(round(0.5 * @rate)..(@rate - 1)) |> peak()
        around = side |> Enum.slice(@rate..(round(1.02 * @rate) - 1)) |> peak()
        assert around <= before * 1.05
      end
    end
  end
end
