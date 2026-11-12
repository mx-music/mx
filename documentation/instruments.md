# Instruments

A part plays its notes on an instrument: one of mx's synths, a synth written in Elixir with `defsynth`, or a sampled instrument made from recordings.
A song names the instrument with `synth:`, and every note it plays gives that instrument options by name, such as `note`, `vel` and `sustain`.
The README lists mx's synths and the options each takes.

## mx's own synths

mx's synths are written in Rust, in the mxs crate's `src/synths`, grouped by family: strings, winds, bowed strings, tuned percussion, drums, organs and the basic waveforms.
Each is built from FunDSP's units and mxs's own nodes in `src/nodes.rs`, such as `modes`, a bank of resonators struck by their input, each fading 60 dB over its own time.

A synth is a name, its options, and a function that builds one note's sound from the note's options:

```rust
let plate = Synth::new("plate")
    .option(Spec::note("note").default(60.0).doc("The pitch."))
    .option(Spec::float("vel").default(0.6).range(0.0, 1.0).doc("How hard the plate is struck."))
    .build(|note, _ctx| {
        let freq = hz(note.number("note"));
        let strike = Net::wrap(Box::new(impulse::<U1>()));
        let struck = modes(strike, &[freq, freq * 2.76], &[1.0, db(-6.0)], &[3.0, 1.2]);
        Note::rings(struck * (0.2 * note.number("vel")) as f32, 4.0)
    });
```

mxs's README shows how to register a synth like this one and play it from Rust.

Each option declares its kind, default, range and documentation, and mx reads those declarations to check a song's options before anything plays.
A note returns its sound together with how it ends, `Note::rings` after a number of seconds or `Note::envelope` by the note's envelope, so mxs knows when to free it as soon as it starts.
Changing a synth's shape takes a rebuild of mxs, which compiling mx does.

## Writing one in Elixir

A song or a library can define its own synths in Elixir with `defsynth`, from a module that uses `Mx.Instrument`.
mxs builds them at run time, so no Rust toolchain is needed, and a synth defined in a song file plays as soon as the file is saved.

```elixir
defmodule Bells do
  use Mx.Instrument

  @doc "A small bell, struck once."
  attr :note, :note, default: 72, doc: "The pitch."
  attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard the bell is struck."

  defsynth bell(hit) do
    freq = hz(hit.note)
    strike = impulse()

    partials =
      for {ratio, level, fade} <- [{1, 0, 2.5}, {2.76, -6, 1.2}, {5.4, -12, 0.6}] do
        strike |> mode(hz: freq * ratio, level: db(level), fade: fade)
      end

    mix(partials)
    |> gain(0.2 * hit.vel)
    |> rings(seconds: 3)
  end
end

song(tempo: 90, music: part(:bell, seq([note(:c5, 1), note(:e5, 1), note(:g5, 2)]), synth: :bell))
```

A `defsynth` does not run when a note plays.
When its module compiles, each clause runs once with the note's options as placeholders, and what the body does with them is recorded as a graph, which mxs builds into a sound when a note starts.
So data written in the module, such as the list of partials above, takes any Elixir, while an option of the note takes only arithmetic, comparisons, `select/3` and the vocabulary.
An `if` on an option fails when the module compiles, naming the file and line.

`Mx.Instrument` documents `attr`, `envelope_attrs`, `defsound`, `defeffect` and the checks made at each step.
`Mx.Instrument.Vocabulary` lists the nodes a synth is built from.
The folder `test/support/instruments` holds a marimba, a flute and a tabla written this way, as longer examples.

## Sampled instruments

`Mx.Sampled` plays a folder of recordings, one key at a time, often at several strengths and in several takes, as a part plays a synth.
The README's notation section, under "Samples, MIDI, OSC, shared values and changes", covers how a song names a folder or a collection of files with `sampled`.

## Instruments measured from recordings

Most of mx's synths imitate a real instrument and were fitted to recordings of it.
Work on one goes through these steps.

1. Find recordings under a free licence, such as the University of Iowa's, VCSL or Freesound's CC0 packs, of single notes or hits at several strengths.
2. Measure them with `mix mx.measure`: `--held` for bowed, blown and organ notes, `--hits` for bars, bells and drums, and plain for plucked and struck strings. It prints each band's level and how fast it fades.
3. Write the design in mxs, and compare it with the recordings by giving `mix mx.measure` the synth with `--synth`.
4. For a held instrument, let `mix mx.fit` search for the values of the synth's options that bring it closest, and write them into the design.
5. Pin the figures in `test/mx/designs_test.exs`, whose tests render the synth and measure it the same way, against the recordings' medians written in the test. They are tagged `engine`.
6. Write a solo for it, in `examples/solo` or a folder of its own under `examples`, from real playing practice, and listen. A synth that passes every figure can still sound wrong, and the ear decides.

The README's section on measuring an instrument describes each command's options and what it prints.
