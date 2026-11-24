defmodule Mx.Paired.Twins do
  @moduledoc """
  Each paired instrument, with the options its two forms are compared and timed at and the seconds rendered.
  """

  @doc "Each twin as `{module, synth, cases, seconds}`, where each case is a note's options."
  def all do
    bols = for bol <- [:na, :tun, :te, :tas, :ghe, :ke], vel <- [0.3, 1], do: [bol: bol, vel: vel]

    [
      {Mx.Paired.Saw, :saw,
       [[note: 45, sustain: 1], [note: 69, cutoff: 80, res: 0.8, sustain: 1]], 2},
      {Mx.Paired.Square, :square,
       [[note: 45, sustain: 1], [note: 69, bend: 2, brightness: 0.2, sustain: 1]], 2},
      {Mx.Paired.Tri, :tri, [[note: 45, sustain: 1], [note: 81, res: 0.9, sustain: 1]], 2},
      {Mx.Paired.Pulse, :pulse,
       [[note: 45, sustain: 1], [note: 60, pulse_width: 0.1, sustain: 1]], 2},
      {Mx.Paired.Noise, :noise, [[sustain: 1], [cutoff: 70, res: 0.7, sustain: 1]], 2},
      {Mx.Paired.FM, :fm,
       [[note: 45, sustain: 1], [note: 64, divisor: 0.5, depth: 3, sustain: 1]], 2},
      {Mx.Paired.Viola, :viola,
       [[note: 60, vel: 0.3], [note: 67, vel: 1, vibrato: 0.5], [note: 55, pizz: 1]], 3},
      {Mx.Paired.DoubleBass, :double_bass,
       [[note: 31, vel: 0.6], [note: 43, vel: 1, brightness: 0.7], [note: 36, pizz: 1, vel: 0.3]],
       3},
      {Mx.Paired.Organ, :organ,
       [[note: 40], [note: 64, loud: 1], [note: 72, loud: 0.5, brightness: 0.3]], 2},
      {Mx.Paired.Harmonium, :harmonium,
       [[note: 52], [note: 64, vel: 1, sustain: 1], [note: 57, vel: 0.3]], 2},
      {Mx.Paired.Accordion, :accordion,
       [[note: 60], [note: 67, vel: 0.3, detune: 0], [note: 55, vel: 1, brightness: 0.8]], 2},
      {Mx.Paired.Kick, :kick, [[], [note: 30, vel: 1], [vel: 0.3, beater: 0]], 2},
      {Mx.Paired.Clap, :clap, [[], [note: 67]], 1},
      {Mx.Paired.Rimshot, :rimshot, [[], [note: 79]], 1},
      {Mx.Paired.Cowbell, :cowbell, [[vel: 0.3], [vel: 1], [note: 68, muted: 1]], 2},
      {Mx.Paired.Clave, :clave, [[vel: 0.3], [note: 93, vel: 1]], 1},
      {Mx.Paired.LowAgogo, :low_agogo, [[vel: 0.3], [vel: 1]], 3},
      {Mx.Paired.HighAgogo, :high_agogo, [[vel: 0.3], [note: 88, vel: 1]], 2},
      {Mx.Paired.LowTimbale, :low_timbale, [[], [note: 60]], 2},
      {Mx.Paired.HighTimbale, :high_timbale, [[], [note: 69]], 2},
      {Mx.Paired.LowBongo, :low_bongo, [[vel: 0.3], [vel: 1], [note: 62, muted: 1]], 2},
      {Mx.Paired.HighBongo, :high_bongo, [[vel: 0.3], [vel: 1], [note: 72, muted: 1]], 2},
      {Mx.Paired.Cabasa, :cabasa, [[vel: 0.3], [vel: 1], [note: 90, rub: 1, sustain: 0.5]], 2},
      {Mx.Paired.Ganza, :ganza, [[vel: 0.3], [vel: 1], [note: 105, up: 1]], 1},
      {Mx.Paired.Shaker, :shaker, [[vel: 0.3], [vel: 1], [note: 98, up: 1]], 2},
      {Mx.Paired.Tambourine, :tambourine, [[vel: 0.3], [vel: 1], [note: 74]], 2},
      {Mx.Paired.TambourineShake, :tambourine_shake,
       [[vel: 0.3], [vel: 1, sustain: 0.6], [note: 64, sustain: 0.1]], 2},
      {Mx.Paired.Vibraphone, :vibraphone,
       [[note: 65, vel: 0.3], [note: 77, vel: 1], [note: 65, vel: 0.6, motor: 5]], 3},
      {Mx.Paired.Piano, :piano,
       [
         [note: 60, vel: 0.3],
         [note: 84, vel: 1],
         [note: 60, vel: 0.3, pedal: 1],
         [note: 84, vel: 1, pedal: 1]
       ], 3},
      {Mx.Paired.Cello, :cello,
       [[note: 48, vel: 0.3, sustain: 2], [note: 60, vel: 1, sustain: 2]], 3},
      {Mx.Paired.FluteFigured, :flute_figured,
       [
         [note: 72, vel: 0.3, sustain: 2],
         [note: 84, vel: 1, sustain: 2],
         [note: 76, vibrato: 0.2, sustain: 2]
       ], 3},
      {Mx.Paired.Marimba, :marimba,
       [[note: 60, vel: 0.3], [note: 72, vel: 1], [note: 48, vel: 0.6, bend: 2, brightness: 0.8]],
       3},
      {Mx.Paired.Xylophone, :xylophone, [[note: 72, vel: 0.3], [note: 84, vel: 1]], 3},
      {Mx.Paired.Glockenspiel, :glockenspiel, [[note: 84, vel: 0.3], [note: 91, vel: 1]], 3},
      {Mx.Paired.Timpani, :timpani, [[note: 43, vel: 0.3], [note: 50, vel: 1]], 3},
      {Mx.Paired.Guitar, :guitar, [[note: 40, vel: 0.3], [note: 64, vel: 1]], 3},
      {Mx.Paired.ElectricBass, :electric_bass, [[note: 28, vel: 0.3], [note: 40, vel: 1]], 3},
      {Mx.Paired.DeepBass, :deep_bass, [[note: 28, vel: 0.3], [note: 36, vel: 1]], 3},
      {Mx.Paired.Harp, :harp, [[note: 48, vel: 0.3], [note: 72, vel: 1]], 3},
      {Mx.Paired.ElectricPiano, :electric_piano, [[note: 52, vel: 0.3], [note: 64, vel: 1]], 3},
      {Mx.Paired.ElectricGuitar, :electric_guitar, [[note: 45, vel: 0.3], [note: 64, vel: 1]], 3},
      {Mx.Paired.Clarinet, :clarinet,
       [
         [note: 60, vel: 0.3, sustain: 3],
         [note: 55, vel: 1, sustain: 3],
         [note: 60, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Oboe, :oboe,
       [
         [note: 69, vel: 0.3, sustain: 3],
         [note: 74, vel: 1, sustain: 3],
         [note: 69, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Bassoon, :bassoon,
       [
         [note: 43, vel: 0.3, sustain: 3],
         [note: 50, vel: 1, sustain: 3],
         [note: 43, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.TenorSax, :tenor_sax,
       [
         [note: 55, vel: 0.3, sustain: 3],
         [note: 62, vel: 1, sustain: 3],
         [note: 55, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Trumpet, :trumpet,
       [
         [note: 67, vel: 0.3, sustain: 3],
         [note: 72, vel: 1, sustain: 3],
         [note: 67, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Trombone, :trombone,
       [
         [note: 48, vel: 0.3, sustain: 3],
         [note: 53, vel: 1, sustain: 3],
         [note: 48, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Horn, :horn,
       [
         [note: 53, vel: 0.3, sustain: 3],
         [note: 60, vel: 1, sustain: 3],
         [note: 53, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Tuba, :tuba,
       [
         [note: 36, vel: 0.3, sustain: 3],
         [note: 41, vel: 1, sustain: 3],
         [note: 36, vel: 0.6, vibrato: 0.3, sustain: 3]
       ], 3.5},
      {Mx.Paired.Pluck, :pluck, [[], [note: 40, ring: 1, coef: 0.6], [note: 76, coef: 0]], 2},
      {Mx.Paired.Caxixi, :caxixi, [[vel: 0.3], [vel: 1]], 2},
      {Mx.Paired.Cajon, :cajon, [[vel: 0.3], [vel: 1], [note: 42, slap: 1]], 2},
      {Mx.Paired.Surdo, :surdo, [[vel: 0.3], [vel: 1], [note: 38, muted: 1]], 2},
      {Mx.Paired.Tamborim, :tamborim, [[vel: 0.3], [note: 74, vel: 1]], 2},
      {Mx.Paired.CrossStick, :cross_stick, [[vel: 0.3], [note: 55, vel: 1]], 2},
      {Mx.Paired.PedalHihat, :pedal_hihat, [[vel: 0.3], [note: 62, vel: 1]], 1},
      {Mx.Paired.Crash, :crash,
       [[vel: 0.3, sustain: 2], [note: 62, vel: 1, sustain: 1, release: 0.5]], 3},
      {Mx.Paired.Snare, :snare, [[vel: 0.3], [vel: 1], [note: 50]], 1},
      {Mx.Paired.LowTom, :low_tom, [[vel: 0.3], [note: 40, vel: 1]], 3},
      {Mx.Paired.MidTom, :mid_tom, [[vel: 0.3], [note: 45, vel: 1]], 3},
      {Mx.Paired.HighTom, :high_tom, [[vel: 0.3], [note: 47, vel: 1]], 3},
      {Mx.Paired.LowConga, :low_conga, [[vel: 0.3], [vel: 1, slap: 1], [note: 50, mute: 1]], 2},
      {Mx.Paired.MidConga, :mid_conga, [[vel: 0.3], [vel: 1, damp: 1], [note: 53, mute: 1]], 2},
      {Mx.Paired.HighConga, :high_conga, [[vel: 0.3], [vel: 1, slap: 1], [mute: 0.5, damp: 0.5]],
       2},
      {Mx.Paired.Berimbau, :berimbau,
       [[vel: 0.3], [vel: 1, coin: 1], [note: 41, gourd: 0], [buzz: 0.5]], 3},
      {Mx.Paired.TimbaleShell, :timbale_shell, [[], [note: 91]], 1},
      {Mx.Paired.Triangle, :triangle,
       [[vel: 0.3, sustain: 2], [note: 72, vel: 1, sustain: 1, release: 0.5]], 3},
      {Mx.Paired.Pandeiro, :pandeiro,
       [
         [stroke: :thumb, vel: 0.3],
         [stroke: :heel, vel: 1],
         [stroke: :slap, muted: 1],
         [stroke: :jingles, note: 51]
       ], 2},
      {Mx.Paired.PandeiroThumb, :pandeiro_thumb, [[vel: 0.3], [vel: 1, muted: 1]], 2},
      {Mx.Paired.PandeiroHeel, :pandeiro_heel, [[vel: 0.3], [vel: 1]], 1},
      {Mx.Paired.PandeiroSlap, :pandeiro_slap, [[vel: 0.3], [vel: 1]], 1},
      {Mx.Paired.PandeiroJingles, :pandeiro_jingles, [[vel: 0.3], [vel: 1]], 2},
      {Mx.Paired.Ride, :ride,
       [[vel: 0.3, sustain: 2], [vel: 1, sustain: 2], [note: 58, bell: 1, sustain: 1]], 3},
      {Mx.Paired.ClosedHihat, :closed_hihat, [[], [note: 96, vel: 0.3], [vel: 1, release: 0.2]],
       2},
      {Mx.Paired.OpenHihat, :open_hihat,
       [[sustain: 1, vel: 0.3], [note: 88, vel: 1, sustain: 0.5, release: 0.3]], 3},
      {Mx.Paired.Cavaquinho, :cavaquinho,
       [
         [note: 67, sustain: 1],
         [note: 74, vel: 1, tremolo: 8, sustain: 1.5],
         [note: 60, vel: 0.3]
       ], 2},
      {Mx.Paired.Bandolim, :bandolim,
       [
         [note: 69, sustain: 1],
         [note: 76, vel: 1, tremolo: 8, sustain: 1.5],
         [note: 62, vel: 0.3]
       ], 2},
      {Mx.Paired.Sitar, :sitar,
       [
         [note: 52, sustain: 2],
         [note: 57, vel: 1, sustain: 2],
         [note: 50, vel: 0.3, bend: 2, sustain: 2]
       ], 3},
      {Mx.Paired.Tanpura, :tanpura, [[], [note: 48, vel: 1, gap: 0.5]], 8},
      {Mx.Paired.Supersaw, :supersaw,
       [[note: 45, sustain: 1], [note: 60, detune: 0.5, bend: -1, sustain: 1]], 2},
      {Mx.Paired.Acid, :acid,
       [
         [note: 33, sustain: 0.5],
         [note: 40, cutoff: 60, res: 0.9, brightness: 0.8, sustain: 0.5]
       ], 2},
      {Mx.Paired.Brass, :brass,
       [
         [note: 52, sustain: 1],
         [note: 64, vel: 1, brightness: 0.8, sustain: 1],
         [note: 45, vel: 0.3, sustain: 1]
       ], 2},
      {Mx.Paired.Flute, :flute,
       [[note: 72, vel: 0.3, sustain: 2], [note: 72, vel: 1, sustain: 2]], 3},
      {Mx.Paired.Tabla, :tabla, bols, 3},
      {Mx.Paired.Violin, :violin,
       [
         [note: 69, vel: 0.3, sustain: 2],
         [note: 69, vel: 1, sustain: 2],
         [note: 69, vel: 0.6, pizz: 1]
       ], 3}
    ]
  end
end
