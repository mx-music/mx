defmodule Mx.EffectsTest do
  use ExUnit.Case, async: true

  alias Mx.Synths
  alias Mx.Engine.Rust

  @moduletag :engine
  @moduletag :tmp_dir
  @rate 48_000

  test "a compressor lowers loud notes, keeps quiet ones, and with a level after it stops a loud loop clipping",
       ctx do
    compressor = fx(:compressor, threshold: 0.2)
    {loud, _} = saw(ctx, [amp: 4], [])
    {quiet, _} = saw(ctx, [amp: 0.1], [])

    assert db(rms(elem(saw(ctx, [amp: 4], [compressor]), 0))) < db(rms(loud)) - 2
    assert_in_delta db(rms(elem(saw(ctx, [amp: 0.1], [compressor]), 0))), db(rms(quiet)), 0.5

    {left, right} = saw(ctx, [amp: 4], [compressor, fx(:level, amp: 0.5)])
    assert peak(loud) > 1
    assert peak(left ++ right) < 1
  end

  test "a chorus widens a centred note, and mix: 0 is dry", ctx do
    {left, right} = saw(ctx, [], [fx(:chorus, [])])
    {dry_left, dry_right} = saw(ctx, [], [])

    assert width(dry_left, dry_right) == 0
    assert width(left, right) > 0.3

    {left, right} = saw(ctx, [], [fx(:chorus, mix: 0)])
    assert difference(left, dry_left) < -100
    assert difference(right, dry_right) < -100
  end

  test "a bitcrusher at 4 bits and 4000 Hz is coarse, and at 16 bits and 44100 Hz is dry but a sample late",
       ctx do
    {dry, _} = saw(ctx, [], [])
    {coarse, _} = saw(ctx, [], [fx(:bitcrusher, bits: 4, sample_rate: 4000)])
    {fine, _} = saw(ctx, [], [fx(:bitcrusher, bits: 16, sample_rate: 44_100)])
    {full, _} = saw(ctx, [], [fx(:bitcrusher, bits: 16, sample_rate: 48_000)])

    assert difference(tl(coarse), Enum.drop(dry, -1)) > 0
    assert difference(tl(fine), Enum.drop(dry, -1)) < -40
    assert difference(tl(full), Enum.drop(dry, -1)) < -60
  end

  test "a tremolo with phase: 1 and depth: 1 at 120 bpm turns a held note fully down and up every half second",
       ctx do
    {left, _} = saw(ctx, [sustain: 2], [fx(:tremolo, phase: 1, depth: 1)])
    halves = left |> levels(0.05) |> Enum.take(40) |> Enum.chunk_every(10)

    lows =
      for half <- halves do
        assert Enum.min(half) < Enum.max(half) / 10
        Enum.find_index(half, &(&1 == Enum.min(half)))
      end

    assert length(Enum.uniq(lows)) == 1
  end

  test "an rlpf rings at its cutoff, where an lpf there does not", ctx do
    {ringing, _} = saw(ctx, [note: 48], [fx(:rlpf, cutoff: 60, res: 0.9)])
    {plain, _} = saw(ctx, [note: 48], [fx(:lpf, cutoff: 60)])

    assert strength(ringing, 60) > 3 * strength(plain, 60)
  end

  test "a bpf keeps the band around its centre and removes the lows and highs", ctx do
    {band, _} = saw(ctx, [note: 48], [fx(:bpf, centre: 72, res: 0.5)])
    {dry, _} = saw(ctx, [note: 48], [])

    assert strength(band, 72) > strength(dry, 72) / 2
    assert strength(band, 48) < strength(dry, 48) / 4
    assert strength(band, 96) < strength(dry, 96) / 4
  end

  test "a flanger sweeps a comb through a saw's harmonics, and more strongly with feedback",
       ctx do
    {dry, _} = saw(ctx, [note: 48, sustain: 2.2], [])
    {flanged, _} = saw(ctx, [note: 48, sustain: 2.2], [fx(:flanger, [])])
    {fed_back, _} = saw(ctx, [note: 48, sustain: 2.2], [fx(:flanger, feedback: 0.8)])

    assert sweep(flanged) > 4 * sweep(dry)
    assert sweep(fed_back) > 1.2 * sweep(flanged)
  end

  test "a wobble with phase: 0.5 at 120 bpm sweeps four times a second, in a different shape for each wave",
       ctx do
    wobble = [phase: 0.5, cutoff_min: 60, cutoff_max: 100]
    {left, _} = saw(ctx, [], [fx(:wobble, wobble)])
    curve = left |> levels(0.025) |> Enum.take(40)

    assert period(curve) == 10

    shapes =
      for wave <- 0..3 do
        {left, _} = saw(ctx, [], [fx(:wobble, [wave: wave] ++ wobble)])
        left |> levels(0.025) |> Enum.take(10) |> normalise()
      end

    for {a, i} <- Enum.with_index(shapes), {b, j} <- Enum.with_index(shapes), i < j do
      assert Enum.sum(Enum.zip_with(a, b, &abs(&1 - &2))) > 0.5
    end
  end

  test "a ping_pong with phase: 0.5 at 120 bpm repeats right, left, right, a quarter second apart, fading",
       ctx do
    chain = [fx(:ping_pong, phase: 0.5, pan_start: 1)]

    {left, right} =
      Rust.render_through(:closed_hihat, [vel: 1.0], 1.2, ctx.tmp_dir, chain)

    [_, l1, l2, l3 | _] = left |> levels(0.25)
    [_, r1, r2, r3 | _] = right |> levels(0.25)

    assert r1 > 4 * l1
    assert l2 > 4 * r2
    assert r3 > 4 * l3
    assert r1 > l2 and l2 > r3
  end

  test "a flanger then a reverb sounds through both, in that order", ctx do
    flanger = fx(:flanger, feedback: 0.8)
    reverb = fx(:reverb, room: 0.8)
    {in_order, _} = saw(ctx, [], [flanger, reverb])
    {reversed, _} = saw(ctx, [], [reverb, flanger])
    {flanged, _} = saw(ctx, [], [flanger])

    assert difference(in_order, flanged) > -10
    assert difference(in_order, reversed) > -20
  end

  test "every new effect slides each option it can change while it plays" do
    for {effect, options} <- [
          compressor: ~w(threshold clamp_time slope_above slope_below relax_time)a,
          chorus: ~w(phase decay)a,
          bitcrusher: ~w(sample_rate bits cutoff)a,
          tremolo: ~w(phase depth)a,
          rlpf: ~w(cutoff res)a,
          bpf: ~w(centre res)a,
          flanger: ~w(phase delay depth decay feedback)a,
          wobble: ~w(phase cutoff_min cutoff_max res pulse_width)a,
          ping_pong: ~w(phase feedback)a
        ],
        option <- options ++ [:amp, :mix, :pre_amp] do
      assert Synths.effect_option?(effect, option), "#{effect} has no #{option}"
      slide = String.to_atom("#{option}_slide")
      assert Synths.effect_option?(effect, slide), "#{effect} has no #{slide}"
    end
  end

  defp fx(effect, opts), do: {effect, Synths.effect_to_seconds(effect, opts, 120)}

  defp saw(ctx, opts, chain) do
    seconds = Keyword.get(opts, :sustain, 1)
    opts = Keyword.merge([note: 60, sustain: seconds, release: 0.01, amp: 0.5], opts)
    Rust.render_through(:saw, opts, seconds + 0.2, ctx.tmp_dir, chain)
  end

  defp rms(samples), do: :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / length(samples))

  defp db(level), do: 20 * :math.log10(level + 1.0e-12)

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()

  defp difference(samples, reference),
    do: db(rms(Enum.zip_with(samples, reference, &(&1 - &2))) / rms(reference))

  # The level of the left minus the right against the level of their sum: 0 for a centred sound.
  defp width(left, right),
    do: rms(Enum.zip_with(left, right, &(&1 - &2))) / rms(Enum.zip_with(left, right, &(&1 + &2)))

  defp levels(samples, seconds),
    do: samples |> Enum.chunk_every(round(seconds * @rate)) |> Enum.map(&rms/1)

  # The amplitude at a note's frequency over the held part of the sound.
  defp strength(samples, note) do
    held = Enum.slice(samples, round(0.2 * @rate), round(0.6 * @rate))
    strength_at(held, 440 * 2 ** ((note - 69) / 12))
  end

  # How much the 8th harmonic of note 48 moves over two seconds in windows of 50 ms, against its mean.
  defp sweep(samples) do
    window = round(0.05 * @rate)
    hz = 8 * 440 * 2 ** ((48 - 69) / 12)

    band_levels =
      samples
      |> Enum.chunk_every(window, window, :discard)
      |> Enum.slice(2, 40)
      |> Enum.map(&strength_at(&1, hz))

    mean = Enum.sum(band_levels) / length(band_levels)

    spread =
      :math.sqrt(Enum.sum(Enum.map(band_levels, &((&1 - mean) ** 2))) / length(band_levels))

    spread / mean
  end

  # The amplitude at a frequency, by the Goertzel algorithm.
  defp strength_at(samples, hz) do
    coefficient = 2 * :math.cos(2 * :math.pi() * hz / @rate)

    {s1, s2} =
      Enum.reduce(samples, {0.0, 0.0}, fn sample, {s1, s2} ->
        {sample + coefficient * s1 - s2, s1}
      end)

    :math.sqrt(max(s1 * s1 + s2 * s2 - coefficient * s1 * s2, 0.0)) / length(samples)
  end

  # The lag, in windows, at which the curve best matches itself.
  defp period(curve) do
    mean = Enum.sum(curve) / length(curve)
    centred = Enum.map(curve, &(&1 - mean))

    Enum.max_by(4..16, fn lag ->
      Enum.sum(Enum.zip_with(centred, Enum.drop(centred, lag), &(&1 * &2))) /
        (length(curve) - lag)
    end)
  end

  defp normalise(curve) do
    {low, high} = Enum.min_max(curve)
    Enum.map(curve, &((&1 - low) / (high - low)))
  end
end
