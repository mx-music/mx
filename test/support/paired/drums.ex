defmodule Mx.Paired.Drums do
  @moduledoc """
  The helpers mxs's drums share, written with defsound so the twins can share them as the drums do.
  """

  use Mx.Instrument

  @ride_bands [200, 300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]
  @hat_bands [200, 300, 500, 800, 1300, 2000, 3200, 5000, 8000, 12_500]
  @jingle_levels [-29, -24, -24.8, -17.5, -13.3, -17, -21.4, 0, -5, 0]
  @jingle_rings [0.55, 0.6, 0.7, 0.5, 0.45, 0.2, 0.15, 0.15, 0.15, 0.15]

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
    bands = Enum.zip([Enum.drop(@ride_bands, first), levels, rings])

    Enum.reduce(bands, 0, fn {centre, decibels, ring}, sound ->
      centre = centre * scale
      level = exp_hit(0.0005, ring)

      band =
        (noise(:white) * level)
        |> bpf(centre, 0.5)
        |> highpass(hz: centre * 0.6)
        |> lowpass(hz: centre * 1.7)
        |> lowpass(hz: centre * 1.7)

      sound + band * (db(decibels) * (200 / centre) ** 0.5)
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

  @doc "A value read at `value` from `table` given at each of `bands`, in a straight line between the two bands around it, and held beyond the ends; numbers only."
  def between(value, bands, table) do
    value = value |> Kernel.max(hd(bands)) |> Kernel.min(List.last(bands))

    index =
      Enum.find_index(Enum.chunk_every(bands, 2, 1, :discard), fn [_, high] -> value <= high end) ||
        length(bands) - 2

    [low, high] = Enum.slice(bands, index, 2)
    along = (value - low) / (high - low)
    Enum.at(table, index) + (Enum.at(table, index + 1) - Enum.at(table, index)) * along
  end

  @doc "The pandeiro's stroke `s` at `f`, struck at `vel`, its head pressed `mute` of the way: a hand ringing the head's modes, a crack of band-passed noise, and the jingles' rattle ringing the discs."
  defsound pandeiro(f, vel, mute, s) do
    pressed = f * 1.1225 ** mute
    rings = Enum.map(s.rings, &(&1 * 0.2 ** mute))

    stick =
      lowpass(
        impulse() + noise(:white) * hit(0.0005, 0.004, -4),
        hz: clamp(800 + vel * 4000, 20, 20_000)
      )

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

  @doc "A tom at the MIDI `note`, tuned from `own`, struck at `vel`: a stick through a pole at 20 Hz ringing the head's modes briefly and long, and the skin's noise with a click, each tilted by vel."
  defsound tom(note, own, vel, t) do
    pitch = hz(note)
    below = min(vel - 0.65, 0)
    above = max(vel - 0.65, 0)
    [corner, low_tilt, mid_tilt, high_tilt] = t.bright

    tilt = fn sound ->
      sound
      |> highshelf(hz: corner, q: 0.707, db: below * low_tilt)
      |> highshelf(hz: 2500, q: 0.707, db: below * mid_tilt + above * high_tilt)
    end

    struck = impulse() + noise(:white) * hit(0.0005, 0.003, -4) * 0.3
    stick = struck |> lowpass(hz: 20, poles: 1) |> lowpass(hz: 2000) |> tilt.()
    freqs = Enum.map(t.ratios, &(pitch * &1))
    levels = Enum.zip_with(t.levels, freqs, &(db(&1) * &2 / 20))
    fades = Enum.map(t.rings, &(&1 * 0.08)) ++ t.rings
    head = mode(stick, hz: freqs ++ freqs, level: levels ++ levels, fade: fades)
    click = (noise(:white) * hit(0.0005, 0.004, -4)) |> highpass(hz: 1500) |> lowpass(hz: 4000)
    # mxs draws the click's noise before the skin's, so it comes first.
    dense = tilt.(click * db(16) + band_noise(t.skin, t.skin_rings, 2, pitch / hz(own)))
    (head + dense * db(-11)) * (db(t.gain) * (vel / 0.65) ** t.curve)
  end

  @doc "A conga at the pitch `pitch`, struck at `vel`, tapped by `mute`, slapped by `slap` and stopped by `damp`: the hand through a pole at 20 Hz ringing the head's modes, the skin's noise and a slap's crack."
  defsound conga(pitch, vel, mute, slap, damp, c) do
    held = 0.09 + 0.25 * vel * vel
    mix = fn open, tapped -> open + (tapped - open) * mute end

    hand =
      impulse() +
        lowpass(noise(:white), hz: clamp(2000 + vel * 6000 + slap * 6000, 20, 20_000)) *
          hit(0.0005, 0.003 + slap * 0.01, -4) * 0.3

    soft = (max(vel, 0.1) / 0.6) ** -c.soft
    freqs = Enum.map(c.ratios, &(pitch * &1))

    levels =
      [c.levels, c.head_tap, freqs]
      |> Enum.zip()
      |> Enum.map(fn {level, tap, freq} -> db(level + mute * tap - slap * 6) * freq / 20 end)

    rings =
      Enum.zip_with(c.rings, c.ratios, fn ring, ratio ->
        ring = ring * mix.(1, 0.7) * (1 - slap * 0.75)
        ring = if ratio > 3, do: ring * mix.(soft, 1), else: ring
        ring + (held - ring) * damp
      end)

    # mxs rings the first mode once more as the hand stops the head, over the same struck sound.
    stopped = db(hd(c.levels) - 12) * damp * hd(freqs) / 20
    rest = lowpass(hand, hz: 20, poles: 1)

    head =
      mode(rest,
        hz: freqs ++ [hd(freqs)],
        level: levels ++ [stopped],
        fade: rings ++ [hd(c.rings)]
      )

    skin_levels = Enum.zip_with(c.skin, c.tap, &(mix.(&1, &2) + slap * 16))

    skin_rings =
      Enum.zip_with(c.skin_rings, c.tap_rings, fn open, tapped ->
        ring = mix.(open * soft, tapped) * (1 - slap * 0.75)
        ring + (0.6 * held - ring) * damp
      end)

    skin =
      highshelf(band_noise(skin_levels, skin_rings, 2, 1),
        hz: 2000,
        q: 0.707,
        db: (vel - 0.6) * 10
      )

    crack = bpf(noise(:white), 3000, 0.7) * hit(0.0005, 0.04, -4) * (slap * 4)
    [darker, brighter] = c.bright
    tone = min(vel - 0.6, 0) / -0.3 * darker + max(vel - 0.6, 0) / 0.4 * brighter
    sound = peak(head + skin + crack, hz: 900, q: 0.5, db: tone)
    sound * (db(c.gain + mute * c.tap_gain) * (vel / 0.6) ** c.curve)
  end

  @doc "A shaker of the design `s`, shaken down, or upward by `up`, at `vel`: random clicks of beads coloured by a sinking bottom, a dip and a falling top, through a burst and a tail."
  defsound shake(pitch, vel, up, s) do
    shape = Enum.zip_with(s.down, s.upward, &(&1 + up * (&2 - &1)))
    at = &Enum.at(shape, &1)
    burst = envelope([{at.(0), 1, 2}, {at.(6), 0, at.(9)}])

    tail =
      envelope([{at.(0), 1, 2}]) * envelope([{0, 1}, {at.(0), 1, :exp}, {at.(1), 0.001, :exp}])

    ending = envelope([{0, 1}, {at.(5), 1}, {0.04, 0}])
    keep = at.(7)

    beads =
      struck(clicks(rate: 4000), attack: 0.0001, fall: 0.001) * noise(:white) +
        noise(:white) * 0.1

    lowest = pitch * at.(3)
    bottom = clamp(envelope([{0, lowest}, {at.(1), lowest * at.(8), :exp}]), 20, 20_000)
    colour = Enum.reduce(1..s.stages, beads, fn _, sound -> highpass(sound, hz: bottom, q: 1) end)
    dipped = peak(colour, hz: clamp(pitch * s.dip, 20, 20_000), q: 2, db: at.(4))
    highest = pitch * at.(2)
    top = clamp(envelope([{0, highest}, {at.(1), highest * s.darken, :exp}]), 20, 20_000)

    bright =
      dipped
      |> lowpass(hz: top, q: 1)
      |> highshelf(hz: clamp(pitch * 1.2, 20, 20_000), q: 0.707, db: (vel - 0.6) * 8)

    # The bright sound plays through the burst and, lowpassed, through the tail: built once.
    mixed =
      share(bright, fn both ->
        darker = lowpass(both, hz: clamp(pitch * at.(10), 20, 20_000), q: 1)
        both * burst * (1 - keep) + darker * tail * keep
      end)

    mixed * ending * (s.gain * vel / 0.6)
  end

  @doc "A tambourine at `scale` times its own pitch, at `vel`, struck, or shaken for `held` seconds when `shaken`: random clicks and a strike ringing the jingles' modes."
  defsound tambourine(scale, vel, held, shaken) do
    rattle = 0.15 + vel * 0.6
    shaking = envelope([{0.005, 1}, {held, 1}, {rattle, 0, -4}])
    # mxs draws the clicks' seed before the strike's noise, so they come first.
    clicked = (clicks(rate: shaking * 400) * shaking) |> highpass(hz: 2500) |> highpass(hz: 2500)

    exciter =
      if shaken do
        clicked
      else
        clicked + (impulse() + highpass(noise(:white), hz: 2000) * hit(0.0005, 0.004, -4)) * 0.3
      end

    jingles = List.flatten(Mx.Paired.Draws.plate(120, 170, 16_000))
    levels = Enum.map(jingles, &db(between(&1, @hat_bands, @jingle_levels)))
    rings = Enum.map(jingles, &between(&1, @hat_bands, @jingle_rings))
    ringing = mode(exciter, hz: Enum.map(jingles, &(&1 * scale)), level: levels, fade: rings)

    lowshelf(ringing, hz: 1000, q: 0.707, db: max(vel - 0.6, 0) * 16) *
      (db(-36) * (vel / 0.6) ** 1.9)
  end
end
