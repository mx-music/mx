defmodule Paredao.Synths do
  @moduledoc "The synths written for Paredão: its 808 bass and its keyboard."

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
  It is a beat and one hook, on five instruments.
  The beat is the genre's: a kick on every beat, with softer strokes between them that make the
  tresillo and one more before the bar ends, a tamborim tuned to the chord that answers the kick,
  loudest on beats two and four, and rolls into the next bar, and a triangle in the baião's
  sixteenths.
  The second and fourth sixteenths of each beat come late, which is the beat's swing.
  The bass is an 808, a synth written in this file: a sine that drops onto its note as it is
  struck, which holds a note from each stroke of the tresillo and glides up where its line slides.
  Its notes go round four bars, G, E flat, B flat and F, which turns to D to come back.
  The hook is a keyboard's, another synth written in this file, which slurs into its high notes
  and back down from them.
  The kick is Karoryfer's Big Rusty Drums, under Creative Commons 0, and the tamborim and the
  triangle are mx's.
  """

  use Mx.Song, tempo: 92

  @room [reverb: [room: 0.5, damp: 0.6, mix: 0.18]]

  @kick {:github, "sfzinstruments/karoryfer.big-rusty-drums",
         "f07ce00df34a46b6b08375be56fe116cf15782bc", "Samples/kick_24/kick/kick/k_vl14_rr1.flac"}

  part :kick, fx: [level: [amp: 0.55]]

  part :bass,
    synth: :sub808,
    defaults: [drive: 0.6],
    fx: [distortion: [distort: 0.55, mix: 0.4], level: [amp: 0.3]]

  part :tamborim, synth: :tamborim, fx: [level: [amp: 1.6]] ++ @room
  part :triangle, synth: :triangle, defaults: [amp: 0.8, pan: 0.3], fx: @room

  part :keyboard,
    synth: :teclado,
    fx: [
      level: [amp: 0.85],
      echo: [phase: 0.75, decay: 2, mix: 0.18],
      reverb: [room: 0.6, damp: 0.5, mix: 0.2]
    ]

  def song, do: swung(seq([intro(), beat(false), break(), beat(true), outro()]))

  # The hook's last two bars with the triangle, and a roll into the beat.
  defp intro do
    together([
      part(:keyboard, hook(2..3)),
      part(:triangle, triangle(2)),
      part(:tamborim, delay(roll(1), 7))
    ])
  end

  # The beat under the hook, twice round, the second time with the hook an octave above as well.
  defp beat(octave?) do
    hook = repeat(hook(0..3), 2)
    high = if octave?, do: [transpose(hook, 12)], else: []

    together([
      part(:kick, kick(4)),
      part(:bass, bass(2)),
      part(:tamborim, together([tamborim(2), delay(roll(1), 31)])),
      part(:triangle, triangle(8)),
      part(:keyboard, together([hook | high]))
    ])
  end

  # The kick and the bass stop for four bars: the tamborim and the triangle under the hook, and a
  # longer roll.
  defp break do
    together([
      part(:tamborim, together([tamborim(1), delay(roll(2), 14)])),
      part(:triangle, triangle(4)),
      part(:keyboard, hook(0..3))
    ])
  end

  # Two more bars of the hook over the kick, and a last stroke.
  defp outro do
    together([
      part(:kick, seq([kick(1), sample(@kick, 4)])),
      part(:keyboard, hook(0..1)),
      part(:bass, delay(note(:g1, 4, sustain: 2), 8))
    ])
  end

  # The second and fourth sixteenths of each beat come 0.035 of a beat late.
  defp swung(music) do
    swing(music, fn beat -> if rem(round(beat * 8), 4) == 2, do: beat + 0.035, else: beat end)
  end

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

  # The kick's two bars: every beat, softer strokes on the tresillo between beats one and three,
  # and the last eighth, with one more a sixteenth before beat four in the second bar.
  defp kick(rounds) do
    bars = [~MX"9..69.6.9...9.7."s, ~MX"9..69.6.9..59.7."s]
    repeat(steps(bars, 0.25, sample: @kick, sustain: 0.35, release: 0.1), rounds)
  end

  # The 808's four bars, a sixteenth to a word: it holds a note from each stroke of the tresillo,
  # and glides up where a note follows a ~.
  # Each note stops a little before its length is up.
  defp bass(rounds) do
    bars = [
      ~MX"g1:3 g1:3 g1:4 bb1:2 d2:2 f2:2",
      ~MX"eb2:3 eb2:3 eb2:1.6 ~g2:2.4 eb2:2 d2:2 c2:2",
      ~MX"bb1:3 bb1:3 bb1:4 d2:2 f2:2 g2:2",
      ~MX"f2:3 f2:3 d2:4 d2:2 d2 ~d3:3"
    ]

    short = fn _step, steps -> [sustain: steps / 4 - 0.05] end
    repeat(steps(bars, 0.25, slide: 0.3, each: short), rounds)
  end

  # The tamborim's four bars in sixteenths, a character to each: a digit is the degree of G minor
  # the stroke is tuned to, and a dot is silence.
  # It plays a degree of each bar's chord around the kick's strokes, loudest on beats two and
  # four.
  defp tamborim(rounds) do
    bars = [
      ~MX"....5..1.1..5.35"s,
      ~MX"....6..3.3..6.16"s,
      ~MX"....5..3.3..5.77"s,
      ~MX"....4..2.2..4.55"s
    ]

    loud = fn step -> [vel: if(rem(step, 16) in [4, 12], do: 0.9, else: 0.55)] end
    repeat(steps(bars, 0.25, notes: scale(), each: loud), rounds)
  end

  # G minor, which the tamborim is tuned to.
  defp scale, do: [:g4, :a4, :bb4, :c5, :d5, :eb5, :f5, :g5]
end
