defmodule Mx.DistortionTest do
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

  # The left side of a render at 120 bpm of the music given.
  defp render(ctx, music) do
    path = write(ctx, "song(tempo: 120, music: #{music})")
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    for <<left::little-float-32, _right::little-float-32 <- data>>, do: left
  end

  # A note of four beats on a synth through the effects given, with the music beside it.
  defp held(synth, note, fx, more \\ "") do
    note = inspect(note)
    plain = if synth == :fm, do: ", depth: 0", else: ""
    note = "note(#{note}, 4, attack: 0#{plain})"
    "part(:tamborzao, together([#{note}#{more}]), synth: #{inspect(synth)}, fx: #{fx})"
  end

  # A second of the sound from half a second in, under a Hann window, with the window.
  defp windowed(samples, from \\ 0.5) do
    window =
      for index <- 0..(@rate - 1), do: 0.5 - 0.5 * :math.cos(2 * :math.pi() * index / @rate)

    sound = samples |> Enum.slice(round(from * @rate), @rate) |> Enum.zip_with(window, &(&1 * &2))
    {sound, window}
  end

  # The energy of the part of a windowed sound at a frequency.
  defp energy({sound, window}, hz) do
    turn = 2 * :math.pi() * hz / @rate

    {re, im} =
      sound
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {sample, index}, {re, im} ->
        {re + sample * :math.cos(turn * index), im + sample * :math.sin(turn * index)}
      end)

    both = if hz == 0, do: 1, else: 2
    squares = Enum.sum_by(window, &(&1 * &1))
    sum = Enum.sum(window)
    both * (re * re + im * im) * squares / :math.pow(sum, 2)
  end

  defp db(energy), do: 10 * :math.log10(max(energy, 1.0e-30))

  # The level in dB of the part of the sound at a frequency, over a second from a time.
  defp part_at(samples, hz, from \\ 0.5), do: samples |> windowed(from) |> energy(hz) |> db()

  # How far in dB the energy on no multiple of the note's frequency, 0 among them, is below the
  # whole sound.
  defp away_from_harmonics(samples, hz) do
    {sound, _window} = windowed = windowed(samples)
    whole = Enum.sum_by(sound, &(&1 * &1))
    on = Enum.sum(for harmonic <- 0..trunc(@rate / 2 / hz), do: energy(windowed, harmonic * hz))
    db(max(whole - on, 0.0) / whole)
  end

  @c7 2093.0045

  @tag :engine
  test "a saw at C7 through distort: 1 or 0.5 keeps its energy on the note's harmonics", ctx do
    for fx <- ["distort: 1", "distort: 0.5", "distort: 1, curve: :hard"] do
      wet = render(ctx, held(:saw, :c7, "[distortion: [#{fx}]]"))
      assert away_from_harmonics(wet, @c7) <= -40
    end
  end

  @tag :engine
  test "a sine at A2 through distort: 0.5 has the third and fifth harmonics a tanh gives it",
       ctx do
    dry = render(ctx, held(:fm, :a2, "[]"))
    wet = render(ctx, held(:fm, :a2, "[distortion: [distort: 0.5]]"))
    plain = Enum.map(dry, &(:math.tanh(&1 * 16) / :math.tanh(16)))

    for harmonic <- [1, 3, 5] do
      assert_in_delta part_at(wet, 110 * harmonic), part_at(plain, 110 * harmonic), 1
    end
  end

  @tag :engine
  test "a saw at A3 through tone: 84 is at least 12 dB quieter at its harmonic by 4000 Hz", ctx do
    open = render(ctx, held(:saw, :a3, "[distortion: [distort: 0.5]]"))
    cut = render(ctx, held(:saw, :a3, "[distortion: [distort: 0.5, tone: 84]]"))
    assert part_at(cut, 3960) <= part_at(open, 3960) - 12
    assert_in_delta part_at(cut, 220), part_at(open, 220), 1
  end

  @tag :engine
  test "a sine through curve: :hard has a flat top for more than a quarter of each cycle", ctx do
    wet = render(ctx, held(:fm, :a4, "[distortion: [distort: 1, curve: :hard]]"))
    levels = wet |> Enum.slice(div(@rate, 2), @rate) |> Enum.map(&abs/1) |> Enum.sort()
    top = Enum.at(levels, div(length(levels), 2))
    flat = Enum.count(levels, &(abs(&1 - top) < 0.03 * top))
    assert flat > length(levels) / 2
  end

  @tag :engine
  test "distort: 0 with mix: 1 passes the sound at its level", ctx do
    dry = render(ctx, held(:fm, :a2, "[]"))
    wet = render(ctx, held(:fm, :a2, "[distortion: [distort: 0, mix: 1]]"))
    assert_in_delta part_at(wet, 110), part_at(dry, 110), 3
  end

  @tag :engine
  test "a change of tone with tone_slide: 2 dulls the part over two beats", ctx do
    moved = ", at([{2, change({:tamborzao, :distortion}, tone: 60, tone_slide: 2)}], 8)"
    fx = "[distortion: [distort: 0.5, tone: 120]]"
    note = "note(:a3, 8, attack: 0)"
    music = "part(:tamborzao, together([#{note}#{moved}]), synth: :saw, fx: #{fx})"
    wet = render(ctx, music)
    level = fn beat -> part_at(wet, 3960, beat / 2) end
    start = level.(0)
    assert level.(2.5) < start - 3
    assert level.(4.5) < level.(2.5) - 12
    assert_in_delta level.(5.5), level.(4.5), 1
  end

  test "a song with curve: :warm is refused when it loads, naming distortion and curve", ctx do
    path = write(ctx, "song(music: #{held(:saw, :a3, "[distortion: [curve: :warm]]")})")
    assert {:error, message} = Mx.Song.load(path)
    assert message =~ "distortion"
    assert message =~ "curve"
    assert message =~ "soft"
  end

  test "the guide describes tone and curve" do
    guide = File.read!("documentation/instruments.md")
    [line] = Regex.run(~r/^- `distortion` .*$/m, guide)
    for option <- ~w(tone curve), do: assert(line =~ "`#{option}`")
  end
end
