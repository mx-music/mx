defmodule Paredao.Synths do
  @moduledoc "The synths written for Paredão: its 808 bass, its snare and its keyboard."

  use Mx.Instrument

  @doc "An 808 bass: a sine that drops onto its note, with overtones, and fades by itself."
  attr :note, :note, default: 29, doc: "The pitch, which a change glides."
  attr :vel, :float, default: 0.8, range: 0..1, doc: "How hard it is struck."
  attr :drive, :float, default: 0.5, range: 0..1, doc: "How loud its overtones are."
  attr :fade, :float, default: 1.6, range: 0.05..10, doc: "The seconds it takes to fade."
  envelope_attrs sustain: 1, release: 0.08

  defsynth sub808(played) do
    pitch = hz(follow(played.note)) * 2 ** envelope([{0, 2.2}, {0.045, 0, -4}])

    overtones =
      for {harmonic, level} <- [{2, 0.35}, {3, 0.22}, {5, 0.08}] do
        sine(hz: pitch * harmonic) |> gain(level * played.drive)
      end

    click =
      noise(:white)
      |> lowpass(hz: 3000, q: 0.7)
      |> perc(attack: 0.0005, release: 0.012)
      |> gain(0.25 * played.vel)

    body =
      mix([sine(hz: pitch) | overtones])
      |> envelope([{0.002, 1}, {played.fade, 0, -3}])
      |> gain(0.5 * played.vel)

    (body + click) |> note_envelope(played)
  end

  @doc "A funk snare: a low knock under a burst of noise about a tenth of a second long, its balance fitted to the genre's records."
  attr :vel, :float, default: 0.8, range: 0..1, doc: "How hard it is struck."
  envelope_attrs sustain: 1, release: 0.05

  defsynth tcha(played) do
    knock =
      sine(hz: 190 * 2 ** envelope([{0, 0.5}, {0.03, 0, -3}]))
      |> envelope([{0.001, 1}, {0.12, 0, -3}])
      |> gain(0.8)

    low = noise(:white) |> bandpass(hz: 360, q: 0.6) |> gain(1.5)
    mid = noise(:white) |> bandpass(hz: 1100, q: 0.6) |> gain(0.55)
    high = noise(:white) |> highpass(hz: 2500, q: 0.7) |> lowpass(hz: 7500, q: 0.7) |> gain(0.6)
    burst = mix([low, mid, high]) |> envelope([{0.001, 1}, {0.06, 0.7, -1}, {0.17, 0, -2}])

    (knock + burst) |> gain(0.5 * played.vel) |> note_envelope(played)
  end

  @doc "A keyboard's lead: two saws a little apart over a square an octave below, through a filter that closes after the stroke."
  attr :note, :note, default: 67, doc: "The pitch, which a change glides."

  attr :vel, :float,
    default: 0.8,
    range: 0..1,
    doc: "How hard it is struck, which opens the filter."

  envelope_attrs sustain: 1, release: 0.12

  defsynth teclado(played) do
    pitch = hz(follow(played.note))
    cutoff = 900 + 5000 * played.vel * envelope([{0, 1}, {0.25, 0.35, -3}])

    mix([saw(hz: pitch * 1.001), saw(hz: pitch * 0.999), square(hz: pitch / 2) |> gain(0.4)])
    |> lowpass(hz: cutoff, q: 1.2)
    |> gain(0.25 * played.vel)
    |> note_envelope(played)
  end
end

defmodule Paredao do
  @moduledoc """
  Paredão, a funk in G minor at 92 bpm, in the manner the genre took from brega funk, written for
  mx and not transcribed from any record.
  It is a beat and one hook, and the beat is the loudest thing in it.
  A bar goes kick, snare, kick, kick, kick, snare, kick: the kick on every beat and an eighth
  after the second, the snare a sixteenth before the second beat and before the fourth.
  The 808, a synth written in this file, sounds under every kick as its boom: a sine that drops
  onto a low note as it is struck and stops before the next stroke, so that the beat has gaps.
  Its note is each bar's, G, E flat, D under B flat, and F, which turns to D to come back, and it
  glides up an octave under the snare's roll.
  The snare is a synth written in this file too, a burst of noise over a low knock, and it rolls
  into every fourth bar.
  A tamborim tuned to the chord plays the tresillo and rolls into the next bar, and a triangle
  plays the baião's sixteenths.
  The second and fourth sixteenths of each beat come late, which is the beat's swing.
  The hook is a keyboard's, another synth written in this file, which slurs into its high notes
  and back down from them.
  The kick is Karoryfer's Big Rusty Drums, under Creative Commons 0, and the tamborim and the
  triangle are mx's.
  """

  use Mx.Song, tempo: 92

  @room [reverb: [decay_seconds: 1.5, damp: 0.6, mix: 0.18]]

  @kick {:karoryfer_big_rusty_drums, "Samples/kick_24/kick/kick/k_vl14_rr1.flac"}

  part :kick, fx: [level: [amp: 0.22]]

  part :bass,
    synth: :sub808,
    defaults: [drive: 0.7],
    fx: [distortion: [distort: 0.4, mix: 0.3], level: [amp: 0.75]]

  part :snare,
    synth: :tcha,
    fx: [
      distortion: [distort: 0.5, mix: 0.4],
      level: [amp: 0.85],
      reverb: [decay_seconds: 1, mix: 0.1]
    ]

  part :tamborim, synth: :tamborim, fx: [level: [amp: 1.4]] ++ @room
  part :triangle, synth: :triangle, defaults: [amp: 0.8, pan: 0.3], fx: @room

  part :keyboard,
    synth: :teclado,
    fx: [
      level: [amp: 0.8],
      echo: [phase: 0.75, decay: 2, mix: 0.18],
      reverb: [decay_seconds: 1.8, damp: 0.5, mix: 0.2]
    ]

  def song, do: swung(seq([intro(), beat(false), break(), beat(true), outro()]))

  # The hook's last two bars with the triangle, and the snare growing from sixteenths to
  # thirty-seconds into the beat.
  defp intro do
    together([
      part(:keyboard, hook(2..3)),
      part(:triangle, triangle(2)),
      part(:snare, build()),
      part(:tamborim, delay(roll(1), 7))
    ])
  end

  # The beat under the hook, twice round, the second time with the hook an octave above as well.
  defp beat(octave?) do
    hook = repeat(hook(0..3), 2)
    high = if octave?, do: [transpose(hook, 12)], else: []

    together([
      part(:kick, kick(2)),
      part(:bass, bass(2)),
      part(:snare, snare(2)),
      part(:tamborim, together([tamborim(2), delay(roll(1), 31)])),
      part(:triangle, triangle(8)),
      part(:keyboard, together([hook | high]))
    ])
  end

  # The kick stops for four bars and the 808 sounds once a bar: the snare, the tamborim and the
  # triangle under the hook, and the snare growing into the beat again.
  defp break do
    together([
      part(:bass, boom(~MX"g1:16 eb1:16 d1:16 f1:16")),
      part(:snare, seq([repeat(steps(~MX"...8.......8...."s, 0.25), 2), build()])),
      part(:tamborim, together([tamborim(1), delay(roll(2), 14)])),
      part(:triangle, triangle(4)),
      part(:keyboard, hook(0..3))
    ])
  end

  # Two more bars of the beat under the hook, and a last stroke.
  defp outro do
    together([
      part(:kick, seq([repeat(kick_bar(), 2), sample(@kick, 4)])),
      part(:snare, seq([repeat(snare_bar(), 2), rest(4)])),
      part(:keyboard, hook(0..1)),
      part(:bass, seq([boom(Enum.take(bass_bars(), 2)), note(:g1, 4)]))
    ])
  end

  # The second and fourth sixteenths of each beat come 0.035 of a beat late.
  defp swung(music), do: feel(music, step: 0.25, push: [0, 0.035, 0, 0.035])

  # Bars of the hook on the keyboard, counted from 0, a sixteenth to a word: a note after a ~ is
  # slurred from the one before it.
  defp hook(bars) do
    hook = [
      ~MX"g4:2 _ g4 ~bb4:2 _ a4 ~g4:2 _ d4:3 _:2",
      ~MX"g4:2 _ g4 ~bb4:2 _ a4 ~g4:4 _:4",
      ~MX"f4:2 _ f4 ~bb4:2 _ a4 ~f4:2 _ d4:3 _:2",
      ~MX"f4:2 _ f4 ~a4:2 _ g4 ~gb4:4 _:4"
    ]

    steps(Enum.slice(hook, bars), 0.25, vel: 0.8, slide: 0.05)
  end

  # The baião's triangle: four sixteenths to a beat, the hand open on the third and closed on the
  # others.
  defp triangle(bars) do
    strokes = [
      o: [vel: 0.75, sustain: 0.2, release: 0.1],
      c: [vel: 0.5, sustain: 0.02, release: 0.15]
    ]

    repeat(steps(~MX"ccocccocccocccoc"s, 0.25, strokes: strokes), bars)
  end

  # A roll on the tamborim in thirty-seconds that climbs the scale and grows, over one beat or
  # two.
  defp roll(beats) do
    pattern = if beats == 1, do: ~MX"12345678"s, else: ~MX"1122334455667788"s
    count = length(pattern)
    steps(pattern, 0.125, notes: scale(), each: fn step -> [vel: 0.3 + 0.6 * step / count] end)
  end

  # The kick's four bars: three of its bar, and a fourth that leaves its last beat to the snare.
  defp kick(rounds) do
    last = steps(~MX"9...9.9.9......."s, 0.25, kick_options())
    repeat(seq([repeat(kick_bar(), 3), last]), rounds)
  end

  # The kick's bar: each beat, and an eighth after the second.
  defp kick_bar, do: steps(~MX"9...9.9.9...9..."s, 0.25, kick_options())

  defp kick_options, do: [sample: @kick, sustain: 0.35, release: 0.1]

  # The snare's four bars: three of its bar, and a fourth that rolls through its last beat.
  defp snare(rounds) do
    last = steps(~MX"...9.......96789"s, 0.25)
    repeat(seq([repeat(snare_bar(), 3), last]), rounds)
  end

  # The snare's bar: a sixteenth before the second beat and before the fourth.
  defp snare_bar, do: steps(~MX"...9.......9...."s, 0.25)

  # Two bars of the snare alone, from sixteenths to thirty-seconds, growing.
  defp build do
    sixteenths = steps(~MX"2.2.3.3.3344"s, 0.25)
    thirty_seconds = steps(~MX"45566778"s, 0.125)
    seq([rest(4), sixteenths, thirty_seconds])
  end

  # The 808 under the kick, twice round its four bars, with a glide up an octave through the
  # fourth bar's last beat.
  defp bass(rounds) do
    glide = steps(~MX"d1:0.8 ~d2:3.2", 0.25, slide: 0.3, vel: 0.5)
    repeat(seq([boom(bass_bars()), glide]), rounds)
  end

  # The 808's four bars, a sixteenth to a word: a note from each stroke of the kick, the fourth
  # bar without its last beat.
  defp bass_bars do
    [
      ~MX"g1:4 g1:2 g1:2 g1:4 g1:4",
      ~MX"eb1:4 eb1:2 eb1:2 eb1:4 eb1:4",
      ~MX"d1:4 d1:2 d1:2 d1:4 d1:4",
      ~MX"f1:4 f1:2 f1:2 d1:4"
    ]
  end

  # The 808 as the kick's boom: each note sounds for a little over a sixteenth and then stops.
  defp boom(bars), do: steps(bars, 0.25, sustain: 0.3)

  # The tamborim's four bars in sixteenths, a character to each: a digit is the degree of G minor
  # the stroke is tuned to, and a dot is silence.
  # It plays a degree of each bar's chord on the tresillo, loudest there, and three strokes in a
  # row before the bar ends.
  defp tamborim(rounds) do
    bars = [
      ~MX"...1..5....1555."s,
      ~MX"...3..6...31666."s,
      ~MX"...3..5....3577."s,
      ~MX"...2..4...42455."s
    ]

    tresillo = [0, 3, 6, 8, 11, 14]
    loud = fn step -> [vel: if(rem(step, 16) in tresillo, do: 0.9, else: 0.55)] end
    repeat(steps(bars, 0.25, notes: scale(), each: loud), rounds)
  end

  # G minor, which the tamborim is tuned to.
  defp scale, do: [:g4, :a4, :bb4, :c5, :d5, :eb5, :f5, :g5]
end
