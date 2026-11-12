# Instruments defined in Elixir

These are the notes of mx-00122.
They propose how instruments are defined once SuperCollider is gone: mx's own in Rust, in the mxs crate, and those of songs and libraries in Elixir, as `defsynth`, built by the engine at run time.
They also propose the engine's public Rust API, which both go through and which someone writing Rust can use directly.
They are a design, not a description of code that exists; nothing here is built yet.

## Why at run time, and not compiled

The prototype in the mxs repository built the piano and the berimbau of mx-00120 twice: as a FunDSP `Net`, a graph built at run time, and as one static FunDSP graph, which is what compiling an instrument to Rust would give.

| | `Net` | static graph |
|---|---|---|
| piano, note 36, one second | 3.8 ms | 3.8 ms |
| piano, note 96, one second | 1.8 ms | 3.8 ms |
| berimbau, one second | 13.3 ms | 10.5 ms |
| building a piano note | 0.008 to 0.025 ms | 0.002 to 0.003 ms |

The piano's cost is its 58 resonators, and a `Net` around them costs nothing measurable.
At note 96 the `Net` is twice as fast, because it leaves out the partials above 16 kHz, while a graph of a fixed shape runs them silent.
The berimbau has more small nodes, envelopes on its partials and three bandpasses in a row on each noise band, and there the static graph is about a fifth faster.
The static berimbau adds 0.34 seconds to a release build of the engine, and a cold build of the engine with FunDSP takes 7.3 seconds, on an Apple M5 Pro.

So compiling gains nothing on the piano and a fifth on the berimbau, and none of mx's instruments needs it for speed.
A `defsynth` is built as a `Net` when a note starts, and never compiled to Rust.

## Where mx's own synths live

mx's own synths are written in Rust, in the mxs crate, with the same public nodes a `defsynth` uses.
The engine is a library in its own right, and someone using it from Rust gets mx's instruments with it, not an empty engine.
Moving mx's instruments off SuperCollider, mx-00123, then needs only the engine's API, and not the tracer.
`defsynth` is for songs, libraries, and examples in Elixir of how an instrument is made, such as the marimba and the flute below.
Changing the shape of one of mx's synths takes a rebuild of the engine, about a second; mix mx.fit changes only figures, which a synth takes as options, as the prototype's cello takes its `eq0` to `eq7`.

## A defsynth

A `defsynth` is a function of one argument, a map of the note's options, and its body returns the sound.
Its name is the synth's name, and a song plays it by that name with options by key, as it names mx's synths today.
`attr` lines before it declare each option the synth takes, as `attr` lines declare a Phoenix function component's assigns: a name, a type, and `default:`, `required:`, `values:`, `range:` and `doc:`.
A module groups synths that belong together, as the drums and the bowed strings are grouped today, and keeps the pieces they share next to them.

The tabla, with each bol's figures from mx's design of it today:

```elixir
defmodule Mx.Instruments.Tabla do
  @moduledoc """
  The tabla, measured from the CC0 "tabla bols" pack by mmiron on Freesound.

  Each bol is a stroke: the head's modes as ratios of the note's frequency, each with a level in dB and the seconds it rings, and noise in bands from 113 Hz up, each with a level in dB and the seconds it fades.
  The bands move with the note, so a note retunes the whole stroke, and a harder stroke is louder and brighter.
  """

  use Mx.Instrument

  @bands [113, 200, 316, 502, 794, 1265, 2000, 2900, 5019, 7937, 12649]

  @doc "A tabla stroke, by its bol, at the bol's own pitch unless the song gives one."
  attr :note, :note, doc: "The pitch; the bol's own pitch when not given."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the stroke is."
  attr :bol, :atom, values: [:na, :tun, :te, :tas, :ghe, :ke], default: :na, doc: "The stroke."

  defsynth tabla(%{bol: :na} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.077,
      modes: [{1.0, -20.2, 0.166}, {1.789, -25.0, 1.291}, {2.6931, 0.0, 0.417}, {3.5927, -25.9, 0.312}, {3.6525, -4.8, 0.312}, {4.3152, -19.3, 0.123}, {4.6887, -4.1, 0.123}],
      noise: [{-90, 0.3}, {-90, 2.02}, {-90, 0.166}, {-90, 1.291}, {-90, 0.417}, {-90, 0.315}, {8.2, 0.166}, {1.5, 0.216}, {-19.9, 0.407}, {-26.1, 0.285}, {-38.7, 0.258}]
    )
    |> rings(seconds: 2)
  end

  defsynth tabla(%{bol: :tun} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.162,
      modes: [{1.0108, 0.0, 2.332}, {1.7922, -27.7, 2.006}, {2.7313, -22.8, 0.502}],
      noise: [{-90, 13.236}, {-90, 2.553}, {-90, 2.332}, {-90, 2.01}, {-90, 0.503}, {-4.0, 0.479}, {-8.0, 0.66}, {-20.3, 1.334}, {-24.2, 0.777}, {-26.8, 1.104}, {-30, 0.43}]
    )
    |> rings(seconds: 3)
  end

  defsynth tabla(%{bol: :te} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.043,
      modes: [{0.3757, -2.4, 0.14}, {0.6049, 0.0, 0.11}, {0.7405, -2.8, 0.14}, {0.9951, -5.3, 0.114}, {1.1908, -2.2, 0.133}, {1.7359, -8.5, 0.128}],
      noise: [{-90, 0.451}, {-90, 0.21}, {-90, 0.13}, {-90, 0.128}, {17.2, 0.173}, {21.0, 0.121}, {17.2, 0.136}, {13.0, 0.124}, {10.1, 0.102}, {5.7, 0.106}, {-8.8, 0.143}]
    )
    |> rings(seconds: 0.6)
  end

  defsynth tabla(%{bol: :tas} = hit) do
    hit
    |> stroke(
      own: 63,
      level: 0.0133,
      modes: [{1.0002, -1.5, 0.34}, {1.2098, 6.7, 0.129}, {1.7796, 12.7, 2.027}, {2.696, 3.2, 0.375}, {3.557, 5.2, 0.261}, {3.6364, 14.5, 0.256}],
      noise: [{-90, 10.448}, {-90, 2.321}, {53.5, 0.12}, {-90, 2.027}, {48, 0.1}, {-90, 0.259}, {23.7, 0.465}, {13.9, 0.546}, {8.1, 0.248}, {-2.0, 0.359}, {-4.0, 0.299}]
    )
    |> rings(seconds: 4)
  end

  defsynth tabla(%{bol: :ghe} = hit) do
    hit
    |> stroke(
      own: 42.25,
      level: 0.14,
      high: 3700,
      modes: [{1.0, 0.0, 3.528}, {1.8376, -28.8, 5.735}, {2.8494, -28.2, 1.599}, {3.0246, -21.0, 1.599}, {4.0406, -36.7, 0.874}, {4.9808, -24.1, 0.553}],
      noise: [{-90, 3.528}, {-90, 5.727}, {-90, 1.629}, {-90, 0.553}, {3.1, 0.433}, {-5.5, 0.453}, {-17.9, 1.63}, {-25.6, 10.221}, {-31.3, 12.0}, {-38.9, 11.327}, {-40.8, 12.0}]
    )
    |> rings(seconds: 5)
  end

  defsynth tabla(%{bol: :ke} = hit) do
    hit
    |> stroke(
      own: 44.75,
      level: 0.081,
      modes: [{1.0, 0.0, 0.06}, {1.8376, -7.1, 0.05}, {2.8494, -10.0, 0.05}, {4.0406, -6.6, 0.04}],
      noise: [{-90, 0.05}, {-90, 0.05}, {-90, 0.05}, {-90, 0.05}, {18.9, 0.05}, {10.3, 0.05}, {4.1, 0.05}, {-2.3, 0.05}, {-5.4, 0.05}, {-12.6, 0.05}, {-23.2, 0.05}]
    )
    |> rings(seconds: 0.1)
  end

  # The bands sit where they do at the bol's own pitch, and move with the note.
  defsoundp stroke(hit, shape) do
    freq = hz(hit.note || shape[:own])
    finger = impulse() |> lowpass(hz: 3000)

    head =
      mix(for {ratio, level, ring} <- shape[:modes] do
        finger |> mode(hz: freq * ratio, level: db(level), fade: ring)
      end)

    centres = List.replace_at(@bands, 7, Keyword.get(shape, :high, 2900))

    hiss =
      mix(for {centre, {level, fade}} <- Enum.zip(centres, shape[:noise]), level > -90 do
        noise(:white)
        |> bandpass(hz: centre * freq / hz(shape[:own]), q: 1 / 0.35, poles: 4)
        |> envelope([{0.001, 1}, {fade, 0.001, :exp}, {0.01, 0}])
        |> gain(db(level))
      end)

    (head + hiss)
    |> highshelf(hz: 1500, q: 1, db: (hit.vel - 0.6) * 5)
    |> gain(shape[:level] * (hit.vel / 0.6) ** 1.5)
  end
end
```

A song names `:tabla` with `bol: :ghe` and plays the fifth clause; `bol: :dha` fails when the song is saved, naming the six bols.
Today these are six synths, `:tabla_na` to `:tabla_ke`, and I propose keeping those names as aliases until the examples move to `:tabla`.

The `attr` lines before the first clause apply to every clause, as in Phoenix, and the clauses pick a stroke by matching on the map, as any function's clauses do.
`note` has no default here, because the tabla's own pitch depends on the bol: a drum hit at its own pitch sends no note, as mx's drums do today, and the body uses `hit.note || 63`.
A synth with one pitch of its own declares it as the default instead, such as `attr :note, :note, default: 60` on the piano.
Each synth declares what it takes: 16 of mx's 78 synths, the kick and the clap among them, take no `vel` today.

An attr's type is its unit, `:note`, `:hz`, `:db`, `:seconds` or `:beats`, or a plain `:float`, `:integer`, `:atom` or `:boolean`.
An attr named `note` is always the synth's pitch as a MIDI note, as every mx synth takes it today; the `:note` type is also for other options in notes, such as a filter's cutoff.
An attr in `:beats`, such as a time, is turned into seconds at the tempo before the note reaches the engine, as mx does for times today.
The declarations drive the checks when a song is written or saved, the sliders in mx's window, the bounds mix mx.fit searches, and the list of options in the synth's generated documentation.

Every synth also takes `amp` and `pan`, which are not declared: the engine scales and pans every synth's sound after its body, as mx's designs do today.
A synth with an envelope declares its seven options, `attack`, `decay`, `decay_level`, `sustain`, `sustain_level`, `attack_level` and `release`, with `envelope_attrs/1`, which takes the defaults that differ for that synth, such as `envelope_attrs(sustain: 0.5, release: 0.2)`, and ends its body with `note_envelope(hit)`.
37 of mx's synths have an envelope, and songs pass its options to many of them, such as `attack: 3` on the ambient example's supersaw pad; the drums have none.

## Pieces of sound

`defsoundp` defines a function a synth can call, private to its module as `defp` is, and `defsound` one that other modules can call, such as a plucked string shared by the guitar, the cavaquinho and the bandolim.
They are plain functions: any arguments, in any order, returning a sound or a value worked out from the note's options, as the marimba's `mallet` below does.
`stroke(hit, shape)` takes the synth's map and a keyword list of figures written in each clause, so a clause pipes `hit` into it.
They are checked as a `defsynth` is, below, and traced into the synth that calls them, as Nx's `defn` calls another `defn`.

## Tracing

`defsynth` does not run when a note plays.
When the module compiles, it runs each clause once with a map whose values are placeholders, and records what the body does with them as a graph, as Nx's `defn` does.
A value a clause matches on, such as `bol: :na`, is in that clause's map as itself, so each clause traces to a graph of its own.
The engine receives those graphs once, when the song loads, picks one by the note's options when the note starts, and builds a `Net` from it.
A `defsynth` written in a song's own file is traced when the song loads or is saved, as the rest of the song's code compiles, and plays at once: the engine builds a graph without compiling anything, so no Rust toolchain is needed.

Arithmetic on options and numbers, such as `freq * ratio` or `4 / ratio`, is recorded as an expression in the graph, and the engine works it out when the note starts, so playing a note needs nothing from Elixir but its options.
Any option can change while a note sounds, gliding to its new value over its `_slide` option, as `note`, `amp` and `pan` do today; what is worked out from it is worked out again every 64 samples while it glides, and stays fixed otherwise.
The tabla's ghe glides its pitch this way, as it does today.
The author never marks which options can change, except that an option a clause matches on picks the graph, so it cannot change while the note sounds.

What is allowed depends on the value, not on the function called:
- Data known when the module compiles, such as numbers, lists and keyword lists written in the module, takes any Elixir: `for`, `Enum`, `Keyword` and the rest. It runs once while tracing and leaves only its result in the graph; `stroke` leaves out the bands at -90 dB this way.
- A placeholder, an option of the note or anything worked out from one, takes only arithmetic, `+`, `-`, `*`, `/` and `**`, comparisons, which pick between two values with `select/3`, and the vocabulary's functions, below.
- Only a `defsynth`, `defsound` or `defsoundp` can work with placeholders; passing one to an ordinary function, of the module or another, fails.

A placeholder used any other way, such as `if hit.vel > 0.5` or `Enum.at(hit.note, 0)`, fails when the module compiles, with the file and line where it was used and what is allowed instead.
Control flow that depends on a note, such as leaving out partials above 16 kHz, is written with `select/3` or a level of 0, and the engine leaves out the nodes that come out silent when it builds the note, which is what made the `Net` piano twice as fast at note 96.
A node left out at the start stays out for the note, even if a later glide would make it sound.

## The vocabulary

The vocabulary uses common names, takes no audio or control rate suffixes, and names each argument by its unit: `hz:`, `db:`, `seconds:`, `q:`.
Its first draft covers what the three instruments of mx-00120 needed, and the units mx's SuperCollider designs use, from the table in [rust-engine.md](rust-engine.md).

Numbers:
- `hz(note)` and `note(hz)`, between a MIDI note and its frequency.
- `db(decibels)` and `decibels(gain)`, between decibels and a gain.
- `log2/1`, `exp/1`, `min/2`, `max/2`, `clamp/3`, `abs/1`, `sin/1` and `cos/1`.
- `select(condition, then, else)`.
- `at(list, index)` and `between(list, points, x)`, which read a list of numbers at a point or between fitted points, as the berimbau's bands do.

Sources:
- `sine/1`, `saw/1`, `square/1`, `triangle/1` and `pulse/2`, each at `hz:`, with `phase:` where it matters.
- `noise(:white)`, `noise(:pink)` and `noise(:brown)`.
- `impulse()`, a single sample at the start of the note.
- `random_walk(hz:, curve:)`, random values joined straight or curved, in place of SuperCollider's LFNoise.

Filters:
- `lowpass/2`, `highpass/2` and `bandpass/2`, at `hz:` with `q:`, with `poles:` for two in a row.
- `peak/2`, `lowshelf/2` and `highshelf/2`, at `hz:` with `q:` and `db:`.
- `mode(hz:, level:, fade:, phase:)`, a resonator set ringing by its input, fading 60 dB over `fade` seconds, which is how the piano's strings, the marimba's bar and the berimbau's wire are made.
- `modes(list, fun)`, a bank of modes, one for each element of the list, that the engine builds without the silent ones.

Shapes over time:
- `envelope(points)`, segments from silence through each point, `{seconds, level}` for a straight one and `{seconds, level, curve}` for a curved one, worked out at every sample.
- `perc(attack:, release:)`, a quick rise and a fall to silence.
- A shape is a value, and piped a sound it scales the sound, as `noise(:white) |> perc(...)` does.
- `swing(hz:, db:)`, a level that swings up and down, as the berimbau's gourd does.
- `follow(seconds:)`, which glides a signal to each new value, in place of SuperCollider's Lag.

Delays:
- `delay(seconds:)`, whose time can change while the note sounds, for vibrato as a swinging delay.
- `feedback(fun)`, a loop through a delay, for a waveguide such as the cello's string.

Mixing and length:
- `mix/1`, a list of signals added together, and `gain(sound, level)`, a sound scaled by a level.
- `stereo(left, right)`, for a synth that makes its own stereo.
- `rings(sound, seconds:)`, for a synth that rings until it fades by itself, below.

Envelopes in the vocabulary are worked out at every sample, not sampled every 2 ms and joined, as FunDSP's `envelope` is.
That keeps a fast shape such as the berimbau's strike exact without a special case, and it takes no jitter, so it needs no seed.

Every node with randomness takes its seed from the synth's name and the order its node is traced in the body, never from where the node sits in the built graph.
FunDSP seeds a noise without a seed of its own from its position in the graph, and jitters when its envelopes sample their shape from that position too.
The prototype's two builds of the piano drew different noise for the hammer's thump, and its two builds of the berimbau, whose noises all had seeds, still differed by 53 dB under the peak; I think the envelopes' jitter is why, and I have not confirmed it.
A synth sounds the same on every run, and a node given `seed:` gets that seed.

## What is checked, and when

Today mx checks a song's synths and options by name: when a song loads, a synth mx does not have and an option a synth does not have each fail with the song's file and line.
It does not check an option's value, and which options are measured in beats is a fixed list kept apart from the synths.

With synths declared as `defsynth`, the checks come from the declarations and happen at three moments.

When a synth's module compiles:
- Anything outside the vocabulary in a body, with the file and line and what is allowed instead.
- A node given an argument it does not take, or missing one it needs, such as `lowpass(q: 0.7)` with no `hz:`.
- A value given in the wrong unit, such as a note where a frequency is expected: `lowpass(hz: note)` fails and suggests `hz(note)`.
- An attr with an unknown type or option, a default outside its range or values, and a clause that matches on an option no attr declares.

When a song is written or saved, before anything plays:
- A synth that does not exist, and an option a synth does not take, as today.
- An option's value outside its range, such as `vel: 1.5` on a synth whose `vel` runs from 0.05 to 1, naming the range.
- A change while a note sounds to an option that cannot change, such as `attack`, as today.

When a note plays, nothing is checked: a value worked out in a loop's pass that falls outside an option's range is held to the range, and the song's output says so once per option.
A song that computes its values is not stopped mid-performance by a value it could not know in advance.

Units are part of a synth's declaration, so the fixed list of options measured in beats goes away: an attr of type `:beats` is converted to seconds at the tempo, and every `_slide` option is.

## How a note ends

The engine needs to know when a note ends when it starts it, so it can free the note on time.
SuperCollider instead frees a note when its envelope finishes, or when its sound falls silent; eight of mx's instruments, the marimba among them, hold their envelope for 1000 seconds and end on silence.

A synth with an envelope lasts as long as its envelope: `attack`, `decay`, `sustain` and `release` added together.
A synth that rings until it fades by itself ends its body with `rings(sound, seconds: ...)`, such as the marimba's fade time worked out from its note or each tabla stroke's length, and its note lasts until the earlier of its envelope's end, if it has one, and that time.
A synth with neither fails when its module compiles.
The engine fades the last 10 ms of every note to silence, so a note cut at its end does not click.

The options that set a note's length cannot change while it sounds, which is why mx already refuses a change to `attack` or `sustain` on a playing note.

## Stereo

A synth makes a mono sound, and the engine pans it with `pan` and scales it with `amp`, as mx's wrapper does today.
A synth that makes its own stereo returns `stereo(left, right)`, and `pan` then balances its two sides, as the stereo sample player does today.

Effects work on stereo, and are defined as synths are, with `defeffect` in a module that uses `Mx.Effect`.
An effect takes two arguments, the sound coming into it and a map of its options, and its body returns the processed sound.
The engine blends it with the dry sound by the effect's `mix` option, as mx's effects do today.

```elixir
defmodule Mx.Effects.Delays do
  @moduledoc "Effects that repeat the sound."

  use Mx.Effect

  @doc "Echoes of the sound, each `feedback` times as loud as the one before."
  attr :seconds, :beats, default: 0.25, range: 0..4, doc: "The time between echoes."
  attr :feedback, :float, default: 0.5, range: 0..0.95, doc: "How loud each echo is against the one before."

  defeffect echo(input, fx) do
    feedback(fn echoes -> (input + echoes * fx.feedback) |> delay(seconds: fx.seconds) end)
  end
end
```

`feedback(fun)` passes `fun` the loop's own output, delayed by the delay inside it, and returns what `fun` returns.

## The marimba and the flute

These sketch two of mx's instruments in this form, from their SuperCollider designs in priv/synthdefs/mx-instruments.scd, as examples of what a `defsynth` can do; mx's own marimba and flute are written in Rust.
Their figures are the ones fitted through scsynth.

```elixir
defmodule Mx.Instruments.Marimba do
  @moduledoc """
  A marimba, measured from the University of Iowa's marimba struck with yarn mallets.

  Each partial is a resonator struck once: the bar's note, its overtones two octaves, a little over three octaves and higher above it, and the odd harmonics of the tube under it.
  The harder the bar is struck, the louder and higher its overtones sound, and a short tap of the mallet sounds above them.
  """

  use Mx.Instrument

  @doc "A marimba note, which rings until it fades by itself unless `sustain` and `release` damp it."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0.05..1, doc: "How hard the bar is struck."
  envelope_attrs(sustain: 1000, release: 0.3)

  defsynth marimba(hit) do
    freq = hz(hit.note)
    vel = hit.vel
    # The seconds a note fades 60 dB in: 4.6 at C2, halving every 17 semitones, and every 16 more above F#5.
    ring = 4.6 * 2 ** ((hit.note - 36) / -17) * 2 ** (max(hit.note - 78, 0) / -16)
    # The tube takes a moment to answer the bar, so the note starts at a quarter of its level.
    swell = 0.45 * 2 ** ((hit.note - 36) / -18)

    fourth = -12 - mallet(freq * 4, 600, 57 * (1 - vel)) - 10 * max(log2(freq * 4 / 900), 0) - 20 * max(log2(370 / (freq * 4)), 0)
    overtone = fn n -> 10 + 14.5 * log2(vel) - mallet(freq * n, 1100, 33.4 - 11.4 * vel) end
    bar = [{4, fourth, 0.3}, {10, overtone.(10), 0.1}, {19, overtone.(19) - 8, 0.08}, {30, overtone.(30) - 12, 0.06}]

    twelfth = select(hit.note < 46, -82, select(hit.note > 62, -82, -22))
    tube = for {n, level} <- [{3, twelfth}, {5, -26}, {7, -26}, {9, -26}], do: {n, level - mallet(freq * n, 600, 12 + 45 * (1 - vel)), 0.35}

    strike = impulse()

    struck =
      mix([strike |> mode(hz: freq, level: 1.25, fade: ring), strike |> mode(hz: freq, level: -1, fade: swell)] ++
        for {n, level, fade} <- bar ++ tube do
          # Overtones above 1.5 kHz die sooner the higher they are.
          strike |> mode(hz: freq * n, level: select(freq * n < 15000, db(level), 0), fade: ring * fade * min(1500 / (freq * n), 1) ** 0.8)
        end)

    tap =
      (noise(:white) |> lowpass(hz: 2200, poles: 6) |> highpass(hz: 1000) |> perc(attack: 0.0005, release: 0.12) |> gain(0.55)) +
        (noise(:white) |> lowpass(hz: 4000, poles: 4) |> highpass(hz: 2500) |> perc(attack: 0.0005, release: 0.05) |> gain(0.3))

    (struck + tap * (vel / 0.6) ** 0.5)
    |> gain(0.1 * (vel / 0.6) ** 1.9)
    |> note_envelope(hit)
    |> rings(seconds: ring * 4 / 3)
  end

  defsoundp mallet(hz, corner, slope), do: slope * max(log2(hz / corner), 0) + 24 * max(log2(hz / 3000), 0)
end
```

```elixir
defmodule Mx.Instruments.Flute do
  @moduledoc """
  A flute, measured from the University of Iowa's flute, from B3 to Db7, played without vibrato, and its vibrato played with it.

  A note's fundamental is louder the higher it is, by more the harder it is played, up to F6; its second and third harmonics stand about as loud, and the rest fall away fast, far faster the softer the note.
  Breath hisses around 2 kHz under the tone, quieter the softer the note, which speaks over a quarter of a second; its vibrato grows as it holds, shallower the softer it is played.
  """

  use Mx.Instrument

  @doc "A flute note."
  attr :note, :note, default: 52, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the note is blown."
  attr :vibrato, :float, default: 0.25, range: 0..1, doc: "The vibrato's depth in semitones, reached as the note holds."
  envelope_attrs(sustain: 0.5, release: 0.2)

  defsynth flute(played) do
    vel = played.vel
    soft = max((1 - vel) / 0.7, 0)
    depth = played.vibrato * vel ** 0.65 * envelope([{0.25, 0}, {1.2, 1, 2}])
    pitch = hz(played.note) * 2 ** (sine(hz: 5) * depth / 12)
    register = clamp(played.note - 59, 0, 30)
    fundamental = register * (0.25 + 0.75 * vel)

    tone =
      mix(for n <- 1..16 do
        overtone = if n == 1, do: 0, else: Enum.at([1, 0, -8], min(n - 2, 2)) - 12 * max(log2(n / 4), 0)
        level = fundamental + overtone + 0.05 * register * log2(n) - soft ** 3.5 * 11 * log2(n)

        sine(hz: pitch * n, phase: :math.pi() * n * (n - 1) / 24)
        |> gain(select(hz(played.note) * n < 16000, db(level), 0))
      end)

    breath = noise(:white) |> bandpass(hz: 2000, q: 1) |> gain(db(-43.5) * vel ** 2)

    (gain(tone, 0.0106) + breath)
    |> envelope([{min(0.25, played.sustain * 0.4), 1, -2}])
    |> note_envelope(played)
  end
end
```

What the sketches show:
- Each is one `defsynth` with its options declared, and the module's doc carries what the SuperCollider design's comments say today.
- Literal data takes any Elixir: the flute's `for`, `if n == 1` and `Enum.at` work on the harmonic's number, and leave a level worked out from the note in the graph.
- The marimba's `mallet` is a `defsoundp` that returns a level, not a sound, and the `fn` in the marimba's body works on the note's options because it is written inside the `defsynth`.
- Partials above 15 kHz on the marimba and 16 kHz on the flute get a level of 0 through `select/3`, and the engine leaves them out, as the `Net` piano does at note 96.
- The marimba starts at a quarter of its level as today: a second resonator at the note's pitch, at a negative level, cancels most of the first while the tube answers.
- The marimba ends at `ring * 4 / 3`: today its note ends when it falls under 0.0001, 80 dB down, and a fade of 60 dB over `ring` reaches 80 dB at four thirds of it.
- The flute's swell, over a quarter of a second or less on a short note, reads `sustain` in seconds, since attrs in beats reach the body converted.

They need from the vocabulary what it already lists, and three things to say plainly:
- `poles:` takes any even number, two for each filter in a row, as the marimba's tap has three low-passes in a row.
- `mode/2` takes a negative `level:`.
- A sine's `phase:` is in radians, so the flute's partials start where its design starts them.

## The engine's Rust API

The engine is the mxs crate, a Rust library in its own right.
mx reaches it through a thin Rustler crate that turns Elixir terms into the API's types and calls it, so a `defsynth` and a synth written in Rust go through the same calls.
How Elixir and Rust talk, the scheduler on FunDSP's Sequencer and how a panic is kept from the BEAM are in [rust-engine.md](rust-engine.md), and this section builds on them.

A synth in Rust is a name, a declaration of its options, and a function that builds one note's sound from them:

```rust
use mxs::{nodes::*, Engine, Event, Note, Spec, Synth};

let plate = Synth::new("plate")
    .option(Spec::note("note").default(60.0).doc("The pitch."))
    .option(Spec::float("vel").default(0.6).range(0.0, 1.0).doc("How hard the plate is struck."))
    .build(|note, ctx| {
        let freq = hz(note.number("note"));
        let struck = impulse() >> (mode(freq, 1.0, 3.0) & mode(freq * 2.76, db(-6.0), 1.2));
        let tap = (noise(ctx.seed()) >> highpass(4000.0, 0.7)) * perc(0.001, 0.02) * 0.1;
        Note::rings((struck + tap) * note.number("vel"), 4.0)
    });

let mut engine = Engine::live()?;
engine.register(plate)?;
engine.play(&[(0.5, Event::note(1, "plate", [("note", 64.0), ("vel", 0.8)]))])?;
```

The pieces:
- `Spec` declares an option as `attr` does: its name, its unit or type, and its default, range, values, whether it is required, and its doc. Elixir reads every registered synth's specs from the engine, so a song that names a synth written in Rust is checked as for a `defsynth`.
- The build function gets the note's options and a context. `note.number/1` reads an option's value when the note starts, `note.follow/1` gives a node that glides to each new value over the option's `_slide`, and `ctx.seed()` gives each random node a seed from the synth's name and the order it asks, the same rule as tracing.
- It returns a `Note`: a mono or stereo sound and how it ends, `Note::rings(sound, seconds)` or `Note::envelope(sound, &note)`, so the engine knows each note's end when it starts it.
- `mxs::nodes` is the vocabulary, the same functions a `defsynth`'s nodes become: `mode`, `perc`, `envelope`, `noise` and the rest, each a FunDSP unit.
- A `defsynth` reaches the engine as a `Graph`, the traced nodes and expressions of each clause with the values it matches on, and `Synth::graph(name, specs, graph)` turns it into a `Synth` whose build function picks the clause, works out the expressions and builds the nodes, leaving out the silent ones.

The engine's calls are the ones mx-00121's boundary needs, each a method on `Engine`:
- `Engine::live()` plays through the default output and `Engine::offline(rate)` renders, for mix mx.fit and mix mx.render.
- `register` adds a synth, and `register_effect` an effect, by name.
- `play` takes events stamped with seconds: a note with its id, synth, options and effect chain, a sample, or a change to a playing note's or effect's options.
- `load_sample`, `start_effect` and `stop_effect`, and `record_input` and `stop_input`, as the boundary's callbacks of the same names.
- `render` returns the frames of a list of events, as `render_note` and `render_through` need.

A name the engine does not know, a synth or an option, is an error returned by the call.
A value outside its range is held to the range when the note plays, as the checks above say, and the engine reports it on a channel that mx reads and prints once per option.
The crate stays at 0.x until mx-00102 decides which of it is promised.

## How a library adds a synth or a node

This answers mx-00102's question for synths and nodes.

- A library adds synths in Elixir: a module that uses `Mx.Instrument`, with `defsynth`s built from the vocabulary and its own `defsound`s, which other libraries can call too. It needs nothing from Rust and plays wherever mx does.
- A new node of the vocabulary, or a synth that must be written in Rust, goes into the mxs crate itself. mx ships its engine precompiled, mx-00126, so a library cannot add Rust code to it, and loading compiled synths into a running engine is out of scope here.
- Someone writing Rust outside mx uses the crate directly, registering their own synths and nodes in their own program.
- How a song names a library's synth without clashing with mx's or another library's is left to mx-00102, with its patterns and helpers.

## Two levels

Synths are for anyone writing music in mx.
A learner plays them by name, as today, and writes a `defsynth` from the vocabulary when none of mx's synths is what a song needs, starting from the examples in Elixir.
The vocabulary's names say what a node does in words a musician knows, and its units are the ones the documentation uses everywhere: notes, hertz, decibels, seconds and beats.

Nodes are for instrument authors, and come in two kinds:
- A `defsound` or `defsoundp` is a function written in the vocabulary, shared by the synths that call it.
- A node of the vocabulary itself, such as `mode` or `follow`, is written in Rust in mxs, and is the same node for a `defsynth` and for a synth written in Rust, mx's own among them; adding one is what the engine's Rust API is for.
