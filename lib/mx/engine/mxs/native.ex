defmodule Mx.Engine.Mxs.Native do
  @moduledoc "The functions mxs, the Rust engine, provides as NIFs."

  version = Mix.Project.config()[:version]
  checkout = File.dir?(Path.expand("../../../../.git", __DIR__))
  configured = Application.compile_env(:rustler_precompiled, [:force_build, :mx], false)

  # A checkout builds mxs, as does `config :rustler_precompiled, :force_build, mx: true`.
  use RustlerPrecompiled,
    otp_app: :mx,
    crate: "mxs_nif",
    version: version,
    base_url: "https://github.com/mx-music/mx/releases/download/v#{version}",
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin
      aarch64-unknown-linux-gnu
      x86_64-unknown-linux-gnu
      x86_64-pc-windows-msvc
    ),
    nif_versions: ["2.15"],
    force_build: checkout or configured

  @doc "Starts an engine with every synth and effect registered: playing live, with the sound card's input or without, or offline."
  def start(_live, _input), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Starts a live engine, with the sound card's input or without, on `{output, input, rate, buffer}`, each nil for the device's default."
  def start_with(_input, _settings), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Each output and input device as `{name, output?, default?, channels, rates, buffers}`, `rates` as lowest and highest pairs, and `buffers` a fewest and most, or nil when the device does not say."
  def devices, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Every synth's options, and those every note, sample, effect and live input takes, as `{synths, note, sample, effects, effect, input}`."
  def catalog, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Each synth's family and the lowest and highest notes it is meant to play, as `{name, family, range}`, the family a string such as \"plucked_strings\" and the range nil when the synth has none."
  def families, do: :erlang.nif_error(:nif_not_loaded)

  @doc "The seconds the engine has played so far."
  def now(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The engine's seconds at which it renders the Unix time given in microseconds, or nil for an offline engine."
  def seconds_at(_engine, _unix_us), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Registers a synth traced by defsynth: its options' declarations, and each clause as the options it matches and its graph."
  def register_graph(_engine, _name, _specs, _clauses), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Registers an effect traced by defeffect: its options' declarations, and the graph of one channel."
  def register_effect_graph(_engine, _name, _specs, _graph) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "The rate the engine plays and renders at, in Hz."
  def rate(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The rate an offline engine renders at, in Hz."
  def offline_rate, do: :erlang.nif_error(:nif_not_loaded)

  @doc "How many channels of the sound card's input the engine reads."
  def inputs(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Plays `{seconds, event}` pairs, each event a note, a sample, an input, a change to sounds playing, or a stop."
  def play(_engine, _events), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Plays events, all at the Unix time given in microseconds, or that time less `origin_us` into an offline engine's seconds, and returns `{reply, warnings}` in one wait for the engine."
  def play_at(_engine, _unix_us, _origin_us, _events), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Loads a sample, and returns its number and channels."
  def load_sample(_engine, _path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The length in seconds of the file at a path, reading only its headers, or why mxs cannot play it."
  def check_sample(_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The loudest sample of the file at a path, as a level from 0, read from all of it."
  def sample_peak(_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The pitch in Hz of each frame of the samples with pYIN, or nil where it finds the frame unvoiced; frame i is centred on sample `i * hop`."
  def pitches(_samples, _rate, _lowest, _highest, _frame, _hop) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "The spectrogram of a stretch of a recording's data as 480 rows of RGB pixels from the top: the data's `{kind, bits, channels}`, the stretch as `{from, count}` in frames, the columns as `{width, hop, size}` in samples, and the columns a second takes, for a line at each second, or nil for none."
  def spectrogram(_data, _format, _rate, _stretch, _columns, _per_second) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "The loudest sample of a recording's data in any channel, as a level from 0, and the RMS level of each of `count` equal slices of its channels' average; the data's format is `{kind, bits, channels}`."
  def levels(_data, _format, _count), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A recording's levels over time, `per_second` rows a second, each as `{second, level, bands, brightness}`, from its data as `Mx.Audio.raw/1` gives it."
  def level_rows(_data, _format, _rate, _per_second), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Lines a recording's data up against a score's frames of the energy in each pitch class, `hop` seconds apart at the score's tempo, the recording starting within its first `free` seconds, as `{seconds, costs, levels}`: the second each frame plays at, the cost there from 0 to 2, and the recording's level in dB every 50 ms."
  def align(_data, _format, _rate, _score, _hop, _free), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The second each sound in a recording starts and its level in dB under the loudest stroke's, as `{second, level}`, from its data as `Mx.Audio.raw/1` gives it."
  def strokes(_data, _format, _rate), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The notes plucked or struck in a recording's data whose first is `note`, or with `whole`, the data as one note from its first sample, as `Mx.Measure` gives them."
  def measure_plucked(_data, _format, _rate, _note, _whole) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "The hits in a recording's data, with their note or nil and how many partials to list or nil, or with `whole`, the data as one hit from its first sample, as `Mx.Measure.Hits` gives them."
  def measure_hits(_data, _format, _rate, _note, _partials, _whole) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "The held notes in a recording's data whose first is `note`, or with `whole`, the data as one held note from its first sample, as `Mx.Measure.Held` gives them."
  def measure_held(_data, _format, _rate, _note, _whole), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The note a recording's data starts with, struck, measured partial by partial as `Mx.Measure.partials/2` gives it."
  def measure_struck(_data, _format, _rate, _note), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Notes made with partials known exactly, measured as a recording of a struck note is, as `mx measure --known` prints them."
  def measure_known, do: :erlang.nif_error(:nif_not_loaded)

  @doc "The seconds each effect of a chain, as `start_effects/2` takes them, sounds on after its input stops, with the options declared in beats in beats at `bpm` when given, or `{:error, message}`."
  def effect_tails(_effects, _bpm), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The notes of a recording's data that holds one of `notes`, MIDI note numbers, or a run of them, as `Mx.Fit.Struck` splits them."
  def split_struck(_data, _format, _rate, _notes, _held), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The notes `measure_known/0` makes, fitted as damped modes, each with a rising term when `rising`."
  def spike_known_modes(_rising), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A recorded struck note's first `seconds` fitted as damped modes, beside its fit partial by partial."
  def spike_strike_modes(_recording, _seconds, _rising), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The figures of struck notes fitted partial by partial, as mxs reads them, from recordings each as `{{data, format, rate}, {from, to}, {note, velocity, seconds, exact}}`, the samples it spans and its note, a MIDI number or between them for a pitch given exactly."
  def fit_struck(_recordings), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far a render of a struck note is from a recording of it, partial by partial and in ERB bands, the recording as `fit_struck/1` takes it and the render as `{data, format, rate}`."
  def check_struck(_recording, _rendered), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far the fit's own render of a struck note is from the recording, the recording as `fit_struck/1` takes it."
  def check_fit_struck(_recording), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A recording of a struck note beside a render of it, or the fit's own render alone when `rendered` is nil, frame by frame at `times` seconds after the strike, as `Mx.Fit.Struck.frames/4` gives them."
  def frames_struck(_recording, _rendered, _times), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A tour for listening of recordings, each as `fit_struck/1` takes it, beside a render as `{data, format, rate}`, as 32-bit floats at the renders' rate."
  def tour_struck(_pairs), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The figures of held notes fitted partial by partial, as mxs reads them, from recordings each as `fit_struck/1` takes them, each note held at one level from where it starts holding when `steady`."
  def fit_held(_recordings, _steady), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far a render of a held note is from a recording of it, as `check_struck/2` takes them."
  def check_held(_recording, _rendered), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far the fit's own render of a held note is from the recording, each note held at one level when `steady`."
  def check_fit_held(_recording, _steady), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Where a recording of a held note holds from and is let go, in seconds after it starts, and the seconds into its span it starts at, as `{held, release, start}`."
  def timing_held(_recording), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A recording of a held note measured partial by partial, as `Mx.Fit.Held.measure/1` gives it."
  def measure_held_partials(_recording), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The magnitudes of `size` samples of a recording's data from the frame `from`, through a periodic Hann window, bins 0 to `size / 2 - 1`."
  def spectrum(_data, _format, _from, _size), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The pitch of each 10 ms frame of a hummed recording's data as a fractional MIDI note, or nil where it has none, as `Mx.Hum` follows it."
  def hum_pitches(_data, _format, _rate), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The strokes of a recording's data, and the recording kept for `stroke_tracks/4`, as `{recording, strokes}`, as `Mx.Measure.Strokes` gives them."
  def measure_strokes(_data, _format, _rate), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The tracks of a recording's stroke at `index`, carrying on into its ring when `alone`, without the harmonics between `{low, high}` Hz or nil, or nil when the stroke has no pitch."
  def stroke_tracks(_recording, _index, _alone, _ignore), do: :erlang.nif_error(:nif_not_loaded)

  @doc "What a piano note played with the options given as `{name, value}` pairs is made of, without playing it, as `{:ok, {harmonics, partners, thump, knock, warnings}}` or `{:error, message}`."
  def piano_parts(_options), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Starts an effect chain of effects, each a name and its options, in order, and returns the chain notes name to play into."
  def start_effects(_engine, _effects), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Removes an effect chain at `at` seconds, once its notes and its effects' tails have ended."
  def stop_effects(_engine, _chain, _at), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Starts the part `name` with effects as `start_effects/2` takes them, and returns the chain notes name to play into it; a part of that name already started is removed first. With `in_beats`, the options the effects declare in beats are given in beats, and follow the engine's tempo as it changes."
  def start_part(_engine, _name, _effects, _in_beats), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sends a share of the sound of the chain `from` into the chain `to` at `level`, besides where it already goes; a send already made takes the level."
  def send_chain(_engine, _from, _to, _level), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Has the effects of `chain` that read a key, such as the compressor, follow the sound of the chain `by`."
  def key_chain(_engine, _chain, _by), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Starts the main effects, which everything the engine plays goes through after its part, in place of those before, and returns the chain a change names to reach them. With `in_beats`, the options the effects declare in beats are given in beats."
  def start_main(_engine, _effects, _in_beats), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Places beat 0 of the engine's tempo map at the Unix time `unix_us` in microseconds, which an offline engine takes as `unix_us` less `origin_us` into its own seconds."
  def place_beats(_engine, _unix_us, _origin_us), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Changes the engine's tempo from `beat` on to `bpm` beats a minute, held with `moving` nil, or with `moving` as `{from, over}`, moving evenly from `from` to `bpm` over `over` beats."
  def set_tempo(_engine, _beat, _bpm, _moving), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The engine's seconds at which `beat` falls, by its tempo map as it is now."
  def beat_seconds(_engine, _beat), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Hands the part `name` a pass over the beats `{from, to}`: `events` as `play_at/4` takes them, each as `{beat, event}`, with the options in beats given in beats.

  `label` is a number of the caller's, and `notice` the beats before `to` at which a subscriber to `"passes"` is told the pass ends, unless another was handed over by then, or nil for no report.
  Returns the reply with the warnings since the last call.
  """
  def pass(_engine, _name, _span, _label, _notice, _events) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "Drops every event in beats handed to the part `name` for `beat` or after that has not started."
  def cut(_engine, _name, _beat), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Removes the part `name` at `at` seconds, once its notes and its effects' tails have ended, if `chain` is still what it plays into; otherwise removes the chain alone."
  def stop_part(_engine, _name, _chain, _at), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Mutes the part `name` now, or lets it be heard again, the sounds handed over before included."
  def mute_part(_engine, _name, _muted), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Solos the part `name` now, or ends its solo: while any part is soloed, only the soloed parts are heard."
  def solo_part(_engine, _name, _soloed), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Renders the next seconds of an offline engine, as the left and right channels in native-endian 32-bit floats."
  def render(_engine, _seconds), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Records `{:input, number}`, numbered from 0, or `{:sample, sample}` to a WAV file from `at` seconds."
  def record(_engine, _path, _source, _at), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Stops the recording `record/4` started."
  def stop_recording(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Records the main output to a WAV file from `at` seconds."
  def record_output(_engine, _path, _at), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Stops the recording `record_output/3` started."
  def stop_recording_output(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Whether any note or sample is still sounding."
  def sounding(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Values held to their ranges since the last call, once for each option, and how many notes were stolen to keep to the voice limit."
  def warnings(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How filling audio went since the last call, as `{buffers, mean, worst, late}`: how many buffers were filled, the time filling took as a share of the time they last, over all of them and at worst, and how many of a live engine's reached the sound card late."
  def buffer_load(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Sends `pid` the engine's reports of the kinds named, `"clock"`, `"output"`, `"voices"`, `"levels"` and `"passes"`, each as `{:mxs_report, report}`, until the subscription returned is given to `unsubscribe/1` or collected, or `pid` is gone.

  A clock report is `{:clock, seconds, unix_us, delay}`: the Unix time in microseconds at which the sound card plays the engine's seconds, and the output's delay in seconds.
  An output report is `{:output, seconds, device, rate, delay_ms}`, with nil for what the device does not say.
  A voices report is `{:voices, seconds, sounding}`, the notes that sound, about once a second.
  A passes report is `{:pass_ending, seconds, part, beat}`, when the part's last pass ends within the notice it was handed with, at `beat`, or `{:pass_started, seconds, part, label, beat}`, when the first event of a pass with another label starts.
  A levels report is `{:levels, seconds, {peak, rms, full_scale}, wave, bands, parts}`, twenty times a second: the output's peak and RMS level, each as `{left, right}`, whether it reached full scale, its wave as 64 points, its level in dB in each of the bands `level_bands/0` gives, and each named part as `{name, peak, rms}`.
  """
  def subscribe(_engine, _pid, _kinds), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The lowest and the highest frequency in Hz of each band of a levels report, the lowest band first."
  def level_bands, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Ends a subscription now, so the engine stops making the reports no one else asked for."
  def unsubscribe(_subscription), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Panics on purpose, so a test can check that a panic raises in Elixir instead of stopping the BEAM."
  def panic_on_purpose, do: :erlang.nif_error(:nif_not_loaded)
end
