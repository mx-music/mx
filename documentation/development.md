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
The tests tagged `audiveris` scan pages of the Bach-Gesellschaft's St Matthew Passion with Audiveris and take two to three minutes; set it up as [Setting up Audiveris](audiveris.md) describes and run them with `mix test --only audiveris`.
The tests tagged `ffmpeg` make videos with `mix mx.video` and read them back, so they need ffmpeg installed; run them with `mix test --only ffmpeg`.

## Lint

`scripts/lint.sh` runs credo, the project's style rules, the formatter, ex_dna's check for duplicated code, a check that every public function has a `@doc`, and a check for compile-time cycles; it needs ripgrep.
