defmodule Mx.EchoTest do
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

  # Both sides added of a render at 120 bpm of the music given, since ping_pong puts each echo on
  # one side.
  defp render(ctx, music) do
    path = write(ctx, "song(tempo: 120, music: #{music})")
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: true) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    for <<left::little-float-32, right::little-float-32 <- data>>, do: left + right
  end

  # The level in dB of the part of the sound at a frequency, over a tenth of a second from a time.
  defp part_at(samples, hz, from) do
    turn = 2 * :math.pi() * hz / @rate

    {re, im} =
      samples
      |> Enum.slice(round(from * @rate), div(@rate, 10))
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {sample, index}, {re, im} ->
        {re + sample * :math.cos(turn * index), im + sample * :math.sin(turn * index)}
      end)

    10 * :math.log10(max(re * re + im * im, 1.0e-30))
  end

  defp tilt(samples, high, low, from) do
    part_at(samples, high, from) - part_at(samples, low, from)
  end

  # A burst of white noise a tenth of a second long through the effects given, on the part given.
  defp burst(fx, part \\ :x, more \\ "") do
    noise = "note(60, 0.2, attack: 0, sustain: 0.18, release: 0.02)"
    "part(#{inspect(part)}, together([#{noise}#{more}]), synth: :noise, fx: #{fx})"
  end

  # How far each of the first three echoes, half a beat apart, tilts from the one before, the
  # first from the dry burst.
  defp steps(ctx, fx, high, low) do
    sound = render(ctx, burst(fx))
    tilts = for echo <- 0..3, do: tilt(sound, high, low, echo * 0.25)

    tilts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [before, later] -> later - before end)
  end

  @tag :engine
  test "each echo is at least 3 dB duller above high_cut than the one before", ctx do
    for step <- steps(ctx, "[echo: [phase: 0.5, decay: 4, high_cut: 84]]", 4000, 500) do
      assert step <= -3
    end
  end

  @tag :engine
  test "each echo is at least 3 dB thinner below low_cut than the one before", ctx do
    for step <- steps(ctx, "[echo: [phase: 0.5, decay: 4, low_cut: 60]]", 100, 1000) do
      assert step <= -3
    end
  end

  @tag :engine
  test "ping_pong's high_cut and low_cut cut each echo as echo's do", ctx do
    for step <- steps(ctx, "[ping_pong: [phase: 0.5, feedback: 0.7, high_cut: 84]]", 4000, 500) do
      assert step <= -3
    end

    for step <- steps(ctx, "[ping_pong: [phase: 0.5, feedback: 0.7, low_cut: 60]]", 100, 1000) do
      assert step <= -3
    end
  end

  @tag :engine
  test "an echo with no cut given keeps each echo's spectrum", ctx do
    for step <- steps(ctx, "[echo: [phase: 0.5, decay: 4]]", 4000, 500) do
      assert_in_delta step, 0, 0.01
    end
  end

  # The echoes die slowly here, so the third is nearly as loud as the first: a quieter echo is
  # rounded off less, and the sine is as quiet as a part in a mix.
  @tag :engine
  test "a sine's third echo through drive has a third harmonic 6 dB stronger than its first",
       ctx do
    for fx <- [
          "echo: [phase: 0.5, drive: 0.5, decay: 32]",
          "ping_pong: [phase: 0.5, drive: 0.5, feedback: 0.95]"
        ] do
      tone = "note(:a4, 0.2, depth: 0, attack: 0, sustain: 0.18, release: 0.02, amp: 0.3)"
      sound = render(ctx, "part(:x, #{tone}, synth: :fm, fx: [#{fx}])")
      third = fn echo -> tilt(sound, 1320, 440, echo * 0.25) end
      assert third.(0) < -40
      assert third.(3) >= third.(1) + 6
    end
  end

  @tag :engine
  test "a change of high_cut with high_cut_slide: 4 dulls the echoes over four beats", ctx do
    bursts =
      for beat <- [2, 4, 6, 8, 10],
          do: "{#{beat}, note(60, 0.2, attack: 0, sustain: 0.18, release: 0.02)}"

    moved = "{2, change({:melodica, :echo}, high_cut: 60, high_cut_slide: 4)}"
    music = "at([#{Enum.join(bursts ++ [moved], ", ")}], 12)"
    fx = "[echo: [phase: 0.5, decay: 1]]"
    sound = render(ctx, burst(fx, :melodica, ", " <> music))

    # How far the first echo of the burst at a beat tilts from the burst itself.
    dulled = fn beat ->
      tilt(sound, 4000, 500, beat / 2 + 0.25) - tilt(sound, 4000, 500, beat / 2)
    end

    assert abs(dulled.(0)) < 1
    assert dulled.(4) < dulled.(0) - 2
    assert dulled.(8) < dulled.(4) - 3
    assert dulled.(8) < -12
    assert_in_delta dulled.(10), dulled.(8), 1
  end

  @tag :engine
  test "the echo rings for its decay whatever its cuts and drive", ctx do
    path =
      write(
        ctx,
        "song(tempo: 120, music: #{burst("[echo: [decay: 6, high_cut: 84, low_cut: 60, drive: 0.5]]")})"
      )

    {:ok, song} = Mx.Song.load(path)
    plain = write(ctx, "song(tempo: 120, music: #{burst("[echo: [decay: 6]]")})")
    {:ok, other} = Mx.Song.load(plain)
    assert Mx.Render.ring_out(song) == Mx.Render.ring_out(other)
  end

  test "the guide describes the three options and dubwise's tape uses them" do
    guide = File.read!("documentation/instruments.md")
    for option <- ~w(high_cut low_cut drive), do: assert(guide =~ "`#{option}`")
    dubwise = File.read!("examples/dubwise.exs")

    assert dubwise =~
             ~r/bus :tape,\s+fx: \[\s+echo: \[[^\]]*high_cut: [^\]]*low_cut: [^\]]*drive: /
  end
end
