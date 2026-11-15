defmodule Mx.Engine.Mxs.Native do
  @moduledoc "The functions mxs, the Rust engine, provides as NIFs."

  use Rustler, otp_app: :mx, crate: "mxs_nif"

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

  @doc "How many channels of the sound card's input the engine reads."
  def inputs(_engine), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Plays `{seconds, event}` pairs, each event a note, a sample, an input, a change to sounds playing, or a stop."
  def play(_engine, _events), do: :erlang.nif_error(:nif_not_loaded)

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

  @doc "Panics on purpose, so a test can check that a panic raises in Elixir instead of stopping the BEAM."
  def panic_on_purpose, do: :erlang.nif_error(:nif_not_loaded)
end
