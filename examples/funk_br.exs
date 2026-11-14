# Paredão, a funk in G minor at 92 bpm, in the manner the genre took from brega funk, written for
# mx and not transcribed from any record.
# It is a beat and one hook, on six instruments.
# The beat is the genre's: a kick on every beat with one more before the bar ends, a tamborim
# tuned to the chord that plays the tresillo and rolls into the next bar, claps on the last
# sixteenth of beat two and on beat four, and a triangle in the baião's sixteenths.
# The bass is an 808, a synth written in this file: a sine that drops onto its note as it is
# struck, which holds a note after each kick and glides up where its line slides.
# Its notes go round four bars, G, E flat, B flat and F, which turns to D to come back.
# The hook is a steel drum's, Jeff Learman's recordings under the Unlicense.
# The kick is Karoryfer's Big Rusty Drums and the claps are the Versilian Community Sample
# Library's, both under Creative Commons 0, and the tamborim and the triangle are mx's.
defmodule Paredao.Synths do
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
end

defmodule Paredao do
  use Mx.Song, tempo: 92

  @room [reverb: [room: 0.5, damp: 0.6, mix: 0.18]]

  @kick {:github, "sfzinstruments/karoryfer.big-rusty-drums",
         "f07ce00df34a46b6b08375be56fe116cf15782bc", "Samples/kick_24/kick/kick/k_vl14_rr1.flac"}
  @claps {:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e",
          "Idiophones/Struck Idiophones/Claps/Clap_rr1.wav"}

  # The steel drum's recorded keys, each file with the note it sounds.
  @steel_drum_keys [{62, "_D4"}, {65, "_F4"}, {66, "Gb4"}, {67, "_G4"}, {69, "_A4"}, {70, "Bb4"}]
  @steel_drum Enum.map(@steel_drum_keys, fn {number, key} ->
                path = "flac/jsdb_0#{number}_#{key}_3.flac"

                {{:github, "sfzinstruments/jlearman.SteelDrum",
                  "dc15a36ad69a43b0d240fcbd0cc78fbc61b2b47e", path}, note: number}
              end)

  part :kick, fx: [level: [amp: 0.6]]

  part :bass,
    synth: :sub808,
    defaults: [drive: 0.6],
    fx: [distortion: [distort: 0.55, mix: 0.4], level: [amp: 0.38]]

  part :tamborim, synth: :tamborim, fx: [level: [amp: 1.4]] ++ @room
  part :clap, fx: [level: [amp: 0.55], reverb: [room: 0.6, damp: 0.5, mix: 0.22]]
  part :triangle, synth: :triangle, defaults: [amp: 0.8, pan: 0.3], fx: @room

  part :steel_drum,
    synth: sampled(@steel_drum),
    defaults: [amp: 0.36, release: 0.15],
    fx: [echo: [phase: 0.75, decay: 2, mix: 0.2], reverb: [room: 0.6, damp: 0.5, mix: 0.22]]

  def song, do: seq([intro(), beat(false), break(), beat(true), outro()])

  # The hook's last two bars with the triangle, and a roll into the beat.
  defp intro do
    together([
      part(:steel_drum, hook(2..3)),
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
      part(:clap, claps(8)),
      part(:triangle, triangle(8)),
      part(:steel_drum, together([hook | high]))
    ])
  end

  # The kick and the bass stop for four bars: the tamborim, the claps and the triangle under the
  # hook, and a longer roll.
  defp break do
    together([
      part(:tamborim, together([tamborim(1), delay(roll(2), 14)])),
      part(:clap, claps(4)),
      part(:triangle, triangle(4)),
      part(:steel_drum, hook(0..3))
    ])
  end

  # Two more bars of the hook over the kick, and a last stroke.
  defp outro do
    last = together([sample(@kick, 4), sample(@claps, 4)])

    together([
      part(:kick, seq([kick(1), last])),
      part(:steel_drum, hook(0..1)),
      part(:bass, delay(note(:g1, 4, sustain: 2), 8))
    ])
  end

  # Bars of the hook on the steel drum, counted from 0, a sixteenth to a word.
  defp hook(bars) do
    hook = [
      ~MX"g4:2 _ g4 bb4:2 _ a4 g4:2 _ d4:3 _:2",
      ~MX"g4:2 _ g4 bb4:2 _ a4 g4:4 _:4",
      ~MX"f4:2 _ f4 bb4:2 _ a4 f4:2 _ d4:3 _:2",
      ~MX"f4:2 _ f4 a4:2 _ g4 gb4:4 _:4"
    ]

    steps(Enum.slice(hook, bars), 0.25, vel: 0.8)
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

  # The kick's two bars: every beat and the last eighth, with softer strokes a sixteenth before
  # beat four and, in the second bar, before beat two.
  defp kick(rounds) do
    bars = [~MX"9...9...9..59.7."s, ~MX"9..59...9..59.7."s]
    repeat(steps(bars, 0.25, sample: @kick, sustain: 0.35, release: 0.1), rounds)
  end

  # The 808's four bars, a sixteenth to a word: it holds a note after each kick, and glides up
  # where a note follows a ~.
  # Each note stops a little before its length is up.
  defp bass(rounds) do
    bars = [
      ~MX"g1:3 _ g1:3 _ bb1:3 _ d2:2 f2:2",
      ~MX"eb2:3 _ eb2:3 _ eb2:1.6 ~g2:2.4 d2:2 c2:2",
      ~MX"bb1:3 _ bb1:3 _ d2:3 _ f2:2 g2:2",
      ~MX"f2:3 _ f2:3 _ d2:3 _ d2 ~d3:3"
    ]

    short = fn _step, steps -> [sustain: steps / 4 - 0.05] end
    repeat(steps(bars, 0.25, slide: 0.3, each: short), rounds)
  end

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

  defp claps(bars), do: repeat(steps(~MX".......7..4.9.4."s, 0.25, sample: @claps), bars)

  # G minor, which the tamborim is tuned to.
  defp scale, do: [:g4, :a4, :bb4, :c5, :d5, :eb5, :f5, :g5]
end
