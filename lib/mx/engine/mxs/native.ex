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

  @doc "Every synth's options, and those every note, sample and effect takes, as `{synths, note, sample, effects, effect}`."
  def catalog, do: :erlang.nif_error(:nif_not_loaded)

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

  @doc "The second each sound in a recording starts and its level in dB under the loudest stroke's, as `{second, level}`, from its data as `Mx.Audio.raw/1` gives it."
  def strokes(_data, _format, _rate), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The notes plucked or struck in a recording's data whose first is `note`, or with `whole`, the data as one note from its first sample, as `Mx.Measure` gives them."
  def measure_plucked(_data, _format, _rate, _note, _whole),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "The hits in a recording's data, with their note or nil and how many partials to list or nil, or with `whole`, the data as one hit from its first sample, as `Mx.Measure.Hits` gives them."
  def measure_hits(_data, _format, _rate, _note, _partials, _whole),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc "The held notes in a recording's data whose first is `note`, or with `whole`, the data as one held note from its first sample, as `Mx.Measure.Held` gives them."
  def measure_held(_data, _format, _rate, _note, _whole), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The note a recording's data starts with, struck, measured partial by partial as `Mx.Measure.partials/2` gives it."
  def measure_struck(_data, _format, _rate, _note), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The notes of a recording's data that holds one of `notes`, MIDI note numbers, or a run of them, as `Mx.Fit.Struck` splits them."
  def measure_known, do: :erlang.nif_error(:nif_not_loaded)
  def split_struck(_data, _format, _rate, _notes, _held), do: :erlang.nif_error(:nif_not_loaded)

  @doc "mx-00181's spike: mx-00177's known notes as damped modes, each with a rising term when `rising`."
  def spike_known_modes(_rising), do: :erlang.nif_error(:nif_not_loaded)

  @doc "mx-00181's spike: a recorded struck note's first `seconds` as damped modes, beside today's fit."
  def spike_strike_modes(_recording, _seconds, _rising), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The figures of struck notes fitted partial by partial, as mxs reads them, from recordings each as `{{data, format, rate}, {from, to}, {note, velocity, seconds, exact}}`, the samples it spans and its note, a MIDI number or between them for a pitch given exactly."
  def fit_struck(_recordings), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far a render of a struck note is from a recording of it, partial by partial and in ERB bands, the recording as `fit_struck/1` takes it and the render as `{data, format, rate}`."
  def check_struck(_recording, _rendered), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A tour for listening of recordings of struck notes, each as `fit_struck/1` takes it, beside a render as `{data, format, rate}`, as 32-bit floats at the renders' rate."
  def check_fit_struck(_recording), do: :erlang.nif_error(:nif_not_loaded)
  def frames_struck(_recording, _rendered, _times), do: :erlang.nif_error(:nif_not_loaded)
  def tour_struck(_pairs), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The figures of held notes fitted partial by partial, as mxs reads them, from recordings each as `fit_struck/1` takes them."
  def fit_held(_recordings), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far a render of a held note is from a recording of it, as `check_struck/2` takes them."
  def check_held(_recording, _rendered), do: :erlang.nif_error(:nif_not_loaded)

  @doc "How far the fit's own render of a held note is from the recording; where a recording holds from and is let go, in seconds after it starts, and the seconds into its span it starts at; and a held note measured partial by partial."
  def check_fit_held(_recording), do: :erlang.nif_error(:nif_not_loaded)
  def timing_held(_recording), do: :erlang.nif_error(:nif_not_loaded)
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

  @doc """
  Sends `pid` the engine's reports of the kinds named, `"clock"`, `"output"` and `"voices"`, each as `{:mxs_report, report}`, until the subscription returned is given to `unsubscribe/1` or collected, or `pid` is gone.

  A clock report is `{:clock, seconds, unix_us, delay}`: the Unix time in microseconds at which the sound card plays the engine's seconds, and the output's delay in seconds.
  An output report is `{:output, seconds, device, rate, delay_ms}`, with nil for what the device does not say.
  A voices report is `{:voices, seconds, sounding}`, the notes that sound, about once a second.
  """
  def subscribe(_engine, _pid, _kinds), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Ends a subscription now, so the engine stops making the reports no one else asked for."
  def unsubscribe(_subscription), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Panics on purpose, so a test can check that a panic raises in Elixir instead of stopping the BEAM."
  def panic_on_purpose, do: :erlang.nif_error(:nif_not_loaded)
end
