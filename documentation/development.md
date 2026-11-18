# Working on mx

## Tests

```sh
mix test
mix test --only engine
```

The tests tagged `engine` play or render sound through mxs, the design tests among them, and are left out of a plain `mix test`.
The test tagged `timing` sends MIDI and OSC for a minute and checks when they arrive; run it with `mix test --only timing`.
The tests tagged `iowa` measure the University of Iowa's guitar recordings; download the mono guitar files from https://theremin.music.uiowa.edu/MISguitar.html, unzip them, and run `MX_IOWA_GUITAR=folder mix test --only iowa`.
The tests tagged `iowa` also measure the Iowa flute played mf, with and without vibrato, from https://theremin.music.uiowa.edu/MISflute.html, in the folder `MX_IOWA_FLUTE` names, and render mx's flute.
They also fit mx's clarinet to the Iowa Bb clarinet, from https://theremin.music.uiowa.edu/MISBbclarinet.html, in the folder `MX_IOWA_CLARINET` names.
The tests tagged `vsco` measure the cowbell hits of the VSCO 2 Community Edition percussion, from https://github.com/sgossner/VSCO-2-CE; run them with `MX_VSCO_PERCUSSION=folder mix test --only vsco`.
The tests tagged `vcsl` measure the Versilian Community Sample Library, from https://github.com/sgossner/VCSL; run them with `MX_VCSL=folder mix test --only vcsl`, where the folder is the library's root, and they render mx's synths.
The tests tagged `ffmpeg` make videos with `mix mx.video` and read them back, so they need ffmpeg installed; run them with `mix test --only ffmpeg`.

## Timing benchmarks

`mix mx.bench` measures whether a song's notes reach the engine in time, against an offline engine, so nothing sounds.
Run it before and after a change to how notes are scheduled, loaded or handed to the engine.

```sh
mix mx.bench lead examples/choro.exs
mix mx.bench saves examples/trap.exs --at 5,10,15
mix mx.bench buffers examples/choro.exs examples/trap.exs examples/afrobeat.exs
```

`lead` prints a row for each of four loads, such as:

```
load,notes,late,least_lead_ms,longest_call_ms
idle,682,0,493.7,5.1
vm_busy,682,0,497.5,1.5
saves,682,0,495.5,4.9
os_busy,682,0,443.9,4.4
```

The lead is the time between a note being handed to the engine and its beat, and mx hands each note over 500 ms ahead, so a least lead near 500 says nothing held the note up, and a late note is one handed over after its beat.
The longest call is the longest time one call that hands notes to the engine took.

`saves` prints a row for each second, with the longest gap between two beat messages to a window, and under them how many times mx loaded the saves and how long each load by the window took.
`buffers` prints, for each song, the time filling a buffer of 512 frames took as a share of the time it lasts, and `over` counts the buffers that took longer than they last, which a sound card would have played as a gap.

`--write FILE` keeps a run's figures, and `--compare FILE` prints each figure that is worse than in such a file by more than a tenth.
The figures of 18 November 2026, measured on a MacBook Pro, are in `bench/`:

```sh
mix mx.bench lead examples/choro.exs --compare bench/lead-choro-2026-11-18.txt
mix mx.bench saves examples/trap.exs --at 5,10,15 --compare bench/saves-trap-2026-11-18.txt
mix mx.bench saves examples/choro.exs --at 5,10,15 --compare bench/saves-choro-2026-11-18.txt
mix mx.bench buffers examples/choro.exs examples/trap.exs examples/afrobeat.exs --compare bench/buffers-2026-11-18.txt
```

The figures move from run to run with what else the machine is doing, the longest call and the longest gap most of all, so a figure named once is a reason to run again, not yet a regression.

## Lint

`scripts/lint.sh` runs credo, the project's style rules, the formatter, ex_dna's check for duplicated code, a check that every public function has a `@doc`, and a check for compile-time cycles; it needs ripgrep.
