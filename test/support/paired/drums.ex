defmodule Mx.Paired.Drums do
  @moduledoc """
  The helpers mxs's drums share, written with defsound so the twins can share them as the drums do.
  """

  use Mx.Instrument

  @ride_bands [200, 300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]

  @doc "A rise over `attack` seconds and a fall over `decay`, both bent by `curve`."
  defsound hit(attack, decay, curve) do
    envelope([{attack, 1, curve}, {decay, 0, curve}])
  end

  @doc "A rise from 0.001 to 1 over `attack` seconds and a fall back to 0.001 over `decay`, both exponential; a first point of no length starts it at 0.001, as the graph's envelopes start at 0."
  defsound exp_hit(attack, decay) do
    envelope([{0, 0.001}, {attack, 1, :exp}, {decay, 0.001, :exp}])
  end

  @doc "A band-pass with a peak of 1, whose width is `rq` times its centre."
  defsound bpf(sound, f, rq) do
    bandpass(sound, hz: f, q: 1 / rq)
  end

  @doc "Bands of noise at the ride's bands from `first`, scaled by `scale`, each struck and fading over its ring."
  defsound band_noise(levels, rings, first, scale) do
    Enum.zip([Enum.drop(@ride_bands, first), levels, rings])
    |> Enum.reduce(0, fn {f, l, r}, sound ->
      f = f * scale
      level = exp_hit(0.0005, r)

      band =
        (noise(:white) * level)
        |> bpf(f, 0.5)
        |> highpass(hz: f * 0.6)
        |> lowpass(hz: f * 1.7)
        |> lowpass(hz: f * 1.7)

      sound + band * (db(l) * (200 / f) ** 0.5)
    end)
  end

  @doc "An agogo bell at `f` struck at `vel`: a stick's click ringing its modes at `ratios` with `levels` and `rings`, a hiss up to `top` at `hiss` and a thump at `thump`, scaled by `gain`."
  defsound agogo(f, vel, ratios, levels, rings, hiss, top, thump, gain) do
    click = impulse() + highpass(noise(:white), hz: 3000) * hit(0.0002, 0.002, -4) * 0.5
    stick = lowpass(click, hz: clamp(4000 + vel * 12_000, 20, 20_000))
    bell = mode(stick, hz: Enum.map(ratios, &(f * &1)), level: levels, fade: rings)

    hissing =
      (noise(:white) |> highpass(hz: 1200) |> highpass(hz: 1200)) * exp_hit(0.0005, 0.2) * hiss

    thumping = bpf(noise(:white), f * 0.47, 0.8) * exp_hit(0.001, 0.15) * thump
    top = clamp(top * (0.4 + vel), 1000, 20_000)

    (bell + lowpass(hissing, hz: top) + thumping) * (gain * vel ** 1.4 / 0.6 ** 1.4)
  end

  @doc "A timbale at `f`: a stick of noise ringing the head's modes, with a click, and the shell's."
  defsound timbale(f) do
    stick = highpass(noise(:white), hz: 1500) * hit(0.0004, 0.008, -4)
    head = Enum.map([1, 1.59, 2.14, 2.65], &(f * &1))
    shell = Enum.map([1, 1.47, 2.09, 2.56], &(f * 4.1 * &1))
    head_levels = Enum.map([1, 0.5, 0.35, 0.2], &(&1 * 0.09))
    head_rings = [0.35, 0.22, 0.15, 0.1]

    struck =
      mode(stick,
        hz: head ++ shell,
        level: head_levels ++ Enum.map([0.4, 0.3, 0.2, 0.15], &(&1 * 0.05)),
        fade: head_rings ++ [0.9, 0.7, 0.5, 0.4]
      )

    struck + mode(impulse(), hz: head, level: head_levels, fade: head_rings)
  end

  @doc "A bongo at `f` struck at `vel`, `mute` of the way from open to muted: a hand ringing the head's modes, quickly and in a tail."
  defsound bongo(f, vel, mute, b) do
    mix = fn a, z -> a + (z - a) * mute end

    hand =
      impulse() +
        lowpass(noise(:white), hz: clamp(3000 + vel * 6000, 20, 20_000)) * hit(0.0005, 0.003, -4) *
          0.3

    levels = Enum.zip_with(b.open, b.muted, fn o, m -> db(mix.(o, m)) end)
    rings = Enum.zip_with(b.open_rings, b.muted_rings, fn o, m -> mix.(o, m) * 1.28 end)
    fast = Enum.zip_with(rings, b.fast, &(&1 * &2))
    tails = Enum.zip_with(levels, b.tail, &(&1 * &2))
    freqs = Enum.map(b.ratios, &(f * &1))
    head = mode(hand, hz: freqs ++ freqs, level: levels ++ tails, fade: fast ++ rings)
    level = b.gain * (vel / 0.6) ** mix.(b.curve0, b.curve1)
    highshelf(head, hz: 1500, q: 0.707, db: (vel - 0.6) * 5) * level
  end

  @doc "A stroke fitted to recordings, at `scale` times its own pitch and struck at `vel`: its partials as measured, rung by a stick of noise, over noise in each of the ride's bands, ringing long and briefly."
  defsound fitted(scale, vel, d) do
    tilt = (vel - 0.6) * 12
    stick = highshelf(noise(:white) * hit(0.0005, 0.004, -4), hz: 2500, q: 0.707, db: tilt)

    partials =
      mode(stick,
        hz: Enum.map(d.partials, fn {f, _, _} -> f * scale end),
        level: Enum.map(d.partials, fn {_, l, _} -> db(l + d.partial_db) end),
        fade: Enum.map(d.partials, fn {_, _, r} -> r end)
      )

    dense =
      band_noise(d.levels, d.rings, 0, scale) +
        band_noise(d.levels, List.duplicate(d.early_ring, 10), 0, scale) * db(d.early_db)

    (partials + highshelf(dense, hz: 2500, q: 0.707, db: tilt) * db(d.dense_db)) * db(d.gain) *
      (vel / 0.6) ** 2
  end

  @doc "A value read at `x` from `table` given at each of `bands`, in a straight line between the two bands around it, and held beyond the ends; numbers only."
  def between(x, bands, table) do
    x = x |> Kernel.max(hd(bands)) |> Kernel.min(List.last(bands))

    k =
      Enum.find_index(Enum.chunk_every(bands, 2, 1, :discard), fn [_, high] -> x <= high end) ||
        length(bands) - 2

    [low, high] = Enum.slice(bands, k, 2)
    along = (x - low) / (high - low)
    Enum.at(table, k) + (Enum.at(table, k + 1) - Enum.at(table, k)) * along
  end

  @doc "The pandeiro's stroke `s` at `f`, struck at `vel`, its head pressed `mute` of the way: a hand ringing the head's modes, a crack of band-passed noise, and the jingles' rattle ringing the discs."
  defsound pandeiro(f, vel, mute, s) do
    pressed = f * 1.1225 ** mute
    rings = Enum.map(s.rings, &(&1 * 0.2 ** mute))

    stick =
      (impulse() + noise(:white) * hit(0.0005, 0.004, -4))
      |> lowpass(hz: clamp(800 + vel * 4000, 20, 20_000))

    skin =
      mode(stick,
        hz: Enum.map([0.974, 1.652, 2.475, 3.25, 4.13], &(pressed * &1)),
        level: s.head,
        fade: rings
      )

    [crack, fall, centre] = s.crack

    body =
      bpf(noise(:white), f * centre, 2) * (hit(0.001, fall, -4) + hit(0.001, fall * 4, -4) * 0.06) *
        crack

    [shake, shaken] = s.jingle
    rattle = noise(:white) * exp_hit(0.001, shaken)

    disc_ratios = [
      22.24,
      24.01,
      25.11,
      29.26,
      32.13,
      35.68,
      40.93,
      83.71,
      85.83,
      87.68,
      91.32,
      92.08,
      102.31,
      106.03
    ]

    disc_levels = [0.25, 0.15, 0.15, 0.2, 0.25, 0.15, 0.15, 0.85, 1, 0.75, 0.55, 0.6, 0.6, 0.8]
    disc_rings = List.duplicate(0.04, 7) ++ List.duplicate(0.08, 7)

    # The rattle rings the discs and sounds itself, so it is shared, its noise drawn once.
    jingles =
      share(rattle, fn rattle ->
        mode(rattle * 0.02,
          hz: Enum.map(disc_ratios, &(f * &1)),
          level: disc_levels,
          fade: disc_rings
        ) +
          highpass(rattle, hz: clamp(f * 20, 20, 20_000)) * 0.3
      end) * shake

    highshelf(skin + body + jingles, hz: 2000, q: 0.707, db: (vel - 0.6) * 5) *
      (s.gain * (vel / 0.6) ** 0.75)
  end
end
