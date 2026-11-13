import Mx

# Paredão, a funk in G minor at 92 bpm, in the manner the genre took from brega funk, written for mx and not transcribed from any record.
# It is a beat and one hook, on six instruments.
# The beat is the genre's: a kick on every beat with one more before the bar ends, a tamborim tuned to the chord that plays the tresillo and rolls into the next bar, claps on the last sixteenth of beat two and on beat four, and a triangle in the baião's sixteenths.
# The bass is an 808, a synth written in this file: a sine that drops onto its note as it is struck, which holds a note after each kick and glides up where its line slides.
# Its notes go round four bars, G, E flat, B flat and F, which turns to D to come back.
# The hook is a steel drum's, Jeff Learman's recordings under the Unlicense.
# The kick is Karoryfer's Big Rusty Drums and the claps are the Versilian Community Sample Library's, both under Creative Commons 0, and the tamborim and the triangle are mx's.
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
  import Mx

  @room [reverb: [room: 0.5, damp: 0.6, mix: 0.18]]

  @kick {:github, "sfzinstruments/karoryfer.big-rusty-drums",
         "f07ce00df34a46b6b08375be56fe116cf15782bc", "Samples/kick_24/kick/kick/k_vl14_rr1.flac"}
  @claps {:github, "sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e",
          "Idiophones/Struck Idiophones/Claps/Clap_rr1.wav"}

  @parts [
    kick: [fx: [level: [amp: 0.6]]],
    bass: [
      synth: :sub808,
      defaults: [drive: 0.6],
      fx: [distortion: [distort: 0.55, mix: 0.4], level: [amp: 0.38]]
    ],
    tamborim: [synth: :tamborim, fx: [level: [amp: 1.4]] ++ @room],
    clap: [fx: [level: [amp: 0.55], reverb: [room: 0.6, damp: 0.5, mix: 0.22]]],
    triangle: [synth: :triangle, defaults: [amp: 0.8, pan: 0.3], fx: @room],
    steel_drum: [
      synth:
        sampled(
          for {number, key} <- [
                {62, "_D4"},
                {65, "_F4"},
                {66, "Gb4"},
                {67, "_G4"},
                {69, "_A4"},
                {70, "Bb4"}
              ] do
            path = "flac/jsdb_0#{number}_#{key}_3.flac"

            {{:github, "sfzinstruments/jlearman.SteelDrum",
              "dc15a36ad69a43b0d240fcbd0cc78fbc61b2b47e", path}, note: number}
          end
        ),
      defaults: [amp: 0.36, release: 0.15],
      fx: [echo: [phase: 0.75, decay: 2, mix: 0.2], reverb: [room: 0.6, damp: 0.5, mix: 0.22]]
    ]
  ]

  # A section's voices, each a part's name and its music; a part named more than once plays all its music together.
  def band(voices) do
    voices
    |> List.flatten()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {name, music} -> part(name, together(music), Keyword.fetch!(@parts, name)) end)
    |> together()
  end

  defp play(name, music), do: {name, music}

  # A voice's music after so many beats of silence.
  defp after_rest({name, music}, beats), do: {name, seq([rest(beats), music])}

  # The kick's two bars: every beat and the last eighth, with softer strokes a sixteenth before beat four and, in the second bar, before beat two.
  def kick(rounds) do
    bars = ["9...9...9..59.7.", "9..59...9..59.7."]
    play(:kick, repeat(steps(bars, 0.25, sample: @kick, sustain: 0.35, release: 0.1), rounds))
  end

  # The 808's four bars in sixteenths: where each note starts, its pitch, how many sixteenths it is held, and the notes it glides to at beats into it.
  @bass [
    [{0, :g1, 3, []}, {4, :g1, 3, []}, {8, :bb1, 3, []}, {12, :d2, 2, []}, {14, :f2, 2, []}],
    [
      {0, :eb2, 3, []},
      {4, :eb2, 3, []},
      {8, :eb2, 4, [{0.4, :g2}]},
      {12, :d2, 2, []},
      {14, :c2, 2, []}
    ],
    [{0, :bb1, 3, []}, {4, :bb1, 3, []}, {8, :d2, 3, []}, {12, :f2, 2, []}, {14, :g2, 2, []}],
    [{0, :f2, 3, []}, {4, :f2, 3, []}, {8, :d2, 3, []}, {12, :d2, 4, [{0.25, :d3}]}]
  ]

  def bass(rounds) do
    bars =
      for bar <- @bass do
        notes =
          for {step, key, held, slides} <- bar do
            changes = for {beat, to} <- slides, do: {beat, note: pitch(to), note_slide: 0.3}
            {step / 4, note(key, 0, sustain: held / 4 - 0.05, changes: changes)}
          end

        at(notes, 4)
      end

    play(:bass, repeat(seq(bars), rounds))
  end

  @scale [:g4, :a4, :bb4, :c5, :d5, :eb5, :f5, :g5]
  @tresillo [0, 3, 6, 8, 11, 14]

  # The tamborim's four bars in sixteenths, a character to each: a digit is the degree of G minor the stroke is tuned to, and a dot is silence.
  # It plays a degree of each bar's chord on the tresillo, loudest there, and three strokes in a row before the bar ends.
  @tamborim [
    "...1..5....1555.",
    "...3..6...31666.",
    "...3..5....3577.",
    "...2..4...42455."
  ]

  def tamborim(rounds) do
    loud = fn step -> [vel: if(rem(step, 16) in @tresillo, do: 0.9, else: 0.55)] end
    play(:tamborim, repeat(steps(@tamborim, 0.25, notes: @scale, each: loud), rounds))
  end

  # A roll on the tamborim in thirty-seconds that climbs the scale and grows.
  def roll(beats) do
    count = round(beats * 8)

    strokes =
      for index <- 0..(count - 1) do
        note = Enum.at(@scale, div(index * 8, count))
        vel = 0.3 + 0.6 * index / count
        at([{0, hit(note: pitch(note), vel: vel)}], 0.125)
      end

    play(:tamborim, seq(strokes))
  end

  def claps(bars), do: play(:clap, repeat(steps(".......7..4.9.4.", 0.25, sample: @claps), bars))

  # The baião's triangle: four sixteenths to a beat, the hand open on the third and closed on the others.
  def triangle(bars) do
    strokes = [
      o: [vel: 0.75, sustain: 0.2, release: 0.1],
      c: [vel: 0.5, sustain: 0.02, release: 0.15]
    ]

    play(:triangle, repeat(steps("ccocccocccocccoc", 0.25, strokes: strokes), bars))
  end

  # The hook's four bars, a sixteenth to a word.
  @hook [
    ~MX"g4:2 _ g4 bb4:2 _ a4 g4:2 _ d4:3 _:2",
    ~MX"g4:2 _ g4 bb4:2 _ a4 g4:4 _:4",
    ~MX"f4:2 _ f4 bb4:2 _ a4 f4:2 _ d4:3 _:2",
    ~MX"f4:2 _ f4 a4:2 _ g4 gb4:4 _:4"
  ]

  # The hook on the steel drum, so many semitones up.
  def hook(bars, up \\ 0), do: play(:steel_drum, transpose(steps(bars, 0.25, vel: 0.8), up))

  # The hook's last two bars with the triangle, and a roll into the beat.
  def intro do
    band([hook(Enum.drop(@hook, 2)), triangle(2), roll(1) |> after_rest(7)])
  end

  # The beat under the hook, twice round, the second time with the hook an octave above as well.
  def beat(octave?) do
    high = if octave?, do: [hook(@hook ++ @hook, 12)], else: []

    band([
      kick(4),
      bass(2),
      tamborim(2),
      claps(8),
      triangle(8),
      hook(@hook ++ @hook),
      high,
      roll(1) |> after_rest(31)
    ])
  end

  # The kick and the bass stop for four bars: the tamborim, the claps and the triangle under the hook, and a longer roll.
  def break do
    band([tamborim(1), claps(4), triangle(4), hook(@hook), roll(2) |> after_rest(14)])
  end

  # Two more bars of the hook over the kick, and a last stroke.
  def outro do
    last = together([sample(@kick, 4), sample(@claps, 4)])

    band([
      play(:kick, seq([elem(kick(1), 1), last])),
      hook(Enum.take(@hook, 2)),
      play(:bass, seq([rest(8), note(:g1, 4, sustain: 2)]))
    ])
  end

  def music, do: seq([intro(), beat(false), break(), beat(true), outro()])
end

song(tempo: 92, music: Paredao.music())
