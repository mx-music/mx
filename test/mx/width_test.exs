defmodule Mx.WidthTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000

  # Both sides of a render at 120 bpm of the music given.
  defp render(ctx, music) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\nsong(tempo: 120, music: #{music})\n")
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    Enum.unzip(frames)
  end

  # Sines at the notes given, held for the beats given, through the effects given.
  defp sines(notes, fx, beats \\ 4, more \\ "") do
    notes = Enum.map_join(notes, ", ", &"note(#{&1}, #{beats}, attack: 0, depth: 0)")
    "part(:rhodes, together([#{notes}#{more}]), synth: :fm, fx: #{fx})"
  end

  defp rms(samples) do
    squares = Enum.sum_by(samples, &(&1 * &1))
    :math.sqrt(squares / length(samples))
  end

  defp db(level), do: 20 * :math.log10(max(level, 1.0e-15))

  # The second of sound from half a second in.
  defp middle(samples), do: Enum.slice(samples, div(@rate, 2), @rate)

  defp apart({left, right}), do: Enum.zip_with(middle(left), middle(right), &(&1 - &2))
  defp added({left, right}), do: Enum.zip_with(middle(left), middle(right), &(&1 + &2))

  # The level in dB of the part of the sound at a frequency, over the middle second.
  defp part_at(samples, hz) do
    turn = 2 * :math.pi() * hz / @rate

    {re, im} =
      samples
      |> middle()
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {sample, index}, {re, im} ->
        {re + sample * :math.cos(turn * index), im + sample * :math.sin(turn * index)}
      end)

    db(:math.sqrt(re * re + im * im))
  end

  # The level of the hundredth of a second from a time.
  defp level_at(samples, seconds) do
    samples |> Enum.slice(round(seconds * @rate), div(@rate, 100)) |> rms()
  end

  # A chord whose left side is twice as loud as its right.
  @leaning "pan: [pan: 0.5]"

  @tag :engine
  test "width: [side: 0] has the same samples on both sides", ctx do
    {dry_left, dry_right} = render(ctx, sines([57, 64], "[#{@leaning}]"))
    assert dry_left != dry_right
    {left, right} = render(ctx, sines([57, 64], "[#{@leaning}, width: [side: 0]]"))
    assert left == right
    assert rms(left) > 0.01
  end

  @tag :engine
  test "width: [side: 1] differs from dry by no more than 100 dB below its peak", ctx do
    {dry_left, dry_right} = render(ctx, sines([57, 64], "[#{@leaning}]"))
    {left, right} = render(ctx, sines([57, 64], "[#{@leaning}, width: [side: 1]]"))
    peak = dry_left |> Enum.map(&abs/1) |> Enum.max()

    for {wet, dry} <- [{left, dry_left}, {right, dry_right}] do
      furthest = wet |> Enum.zip_with(dry, &abs(&1 - &2)) |> Enum.max()
      assert furthest <= peak * 1.0e-5
    end
  end

  @tag :engine
  test "width: [side: 2] makes the difference between the sides 6 dB louder and keeps their sum",
       ctx do
    dry = render(ctx, sines([57, 64], "[#{@leaning}]"))
    wide = render(ctx, sines([57, 64], "[#{@leaning}, width: [side: 2]]"))
    assert_in_delta db(rms(apart(wide))) - db(rms(apart(dry))), 6.02, 0.5
    assert_in_delta db(rms(added(wide))) - db(rms(added(dry))), 0, 0.1
  end

  # MIDI notes 35 and 95 are at 61.7 Hz and 1975.5 Hz.
  @tag :engine
  test "mono_below: 48 puts a low tone on the left in the centre and leaves a high one", ctx do
    fx = "[pan: [pan: -1], width: [mono_below: 48]]"
    {left, right} = render(ctx, sines([35, 95], fx))
    assert_in_delta part_at(left, 61.735), part_at(right, 61.735), 1
    assert part_at(right, 1975.533) <= part_at(left, 1975.533) - 30
  end

  @tag :engine
  test "a change of side with side_slide: 2 narrows the part over two beats", ctx do
    moved = ", at([{2, change({:rhodes, :width}, side: 0, side_slide: 2)}], 8)"
    {left, right} = render(ctx, sines([57], "[pan: [pan: -1], width: []]", 8, moved))
    share = fn beat -> level_at(right, beat / 2) / level_at(left, beat / 2) end
    assert share.(1) < 0.01
    assert share.(3) > 0.2 and share.(3) < 0.5
    assert_in_delta share.(4.5), 1, 0.01
    assert_in_delta share.(6), 1, 0.01
  end

  # The triangle of a tremolo is loudest three quarters into each cycle of half a second.
  @tag :engine
  test "tremolo with spread: 1 is loudest on the left when it is quietest on the right", ctx do
    fx = "[tremolo: [phase: 1, depth: 1, spread: 1]]"
    {left, right} = render(ctx, sines([57], fx, 6))
    peak = left |> Enum.map(&abs/1) |> Enum.max()
    loud = 0.9 * peak / :math.sqrt(2)
    quiet = 0.1 * peak / :math.sqrt(2)

    for cycle <- 0..3 do
      assert level_at(left, 0.37 + cycle * 0.5) > loud
      assert level_at(right, 0.37 + cycle * 0.5) < quiet
      assert level_at(right, 0.62 + cycle * 0.5) > loud
      assert level_at(left, 0.62 + cycle * 0.5) < quiet
    end
  end

  @tag :engine
  test "slicer with spread: 1 sounds on one side at a time", ctx do
    {left, right} = render(ctx, sines([57], "[slicer: [phase: 1, spread: 1]]", 6))
    frames = left |> Enum.zip(right) |> Enum.take(2 * @rate)
    assert Enum.all?(frames, fn {left, right} -> left == 0.0 or right == 0.0 end)
    assert Enum.count(frames, fn {left, _right} -> left != 0.0 end) > 0.9 * @rate
    assert Enum.count(frames, fn {_left, right} -> right != 0.0 end) > 0.9 * @rate
  end

  @tag :engine
  test "tremolo and slicer given no spread move both sides together", ctx do
    for fx <- ["tremolo: [phase: 0.5, depth: 0.4, wave: 3]", "slicer: [phase: 0.5]"] do
      {left, right} = render(ctx, sines([57], "[#{fx}]"))
      assert left == right
    end
  end

  test "the guide lists width, and spread under tremolo and slicer" do
    guide = File.read!("documentation/instruments.md")
    [width] = Regex.run(~r/^- `width` .*$/m, guide)
    for option <- ~w(side mono_below), do: assert(width =~ "`#{option}`")

    for effect <- ~w(tremolo slicer) do
      [line] = Regex.run(~r/^- `#{effect}` .*$/m, guide)
      assert line =~ "`spread`"
    end
  end
end
