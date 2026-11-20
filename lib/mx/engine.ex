defmodule Mx.Engine do
  @moduledoc """
  The boundary between mx and the engine that makes its sound.

  mx works out every note's time and options on its side, and hands the engine events stamped with the Unix time in microseconds they play at, with their times already in seconds.
  An event is one of:

    * `{:note, id, synth, note, params, chain}`, a note of a synth, with its pitch as `note`, or nil for a drum's own pitch.
    * `{:sample, id, sample, params, chain}`, a sample as `prepare` or `load_sample` handed it back.
    * `{:set, target, params}`, a change to sounds already playing: `{:sounds, ids}`, `{:part, chain}` for every note playing in a chain, or `{:effect, chain, index}` for one of its effects.
    * `{:held, id, synth, note, params, chain}`, a note that sounds until a release lets it go, given no length.
    * `{:release, ids}`, which lets those held notes go, each fading over its synth's release.
    * `{:stop, ids}`, which cuts those sounds over 10 ms.

  It also renders notes offline, for measuring and fitting synths.
  `id` is nil for a sound nothing changes later, and otherwise one `new_id/0` gave; `chain` is nil, or an effect chain as `start_fx` handed it back, which the note plays into.
  """

  @type id :: term()
  @type chain :: term()
  @type params :: keyword(number())
  @type target :: {:sounds, list(id())} | {:part, chain()} | {:effect, chain(), non_neg_integer()}
  @type event ::
          {:note, id() | nil, atom(), number() | [number()] | nil, params(), chain() | nil}
          | {:sample, id() | nil, term(), params(), chain() | nil}
          | {:set, target(), params()}
          | {:held, id(), atom(), number() | nil, params(), chain() | nil}
          | {:release, list(id())}
          | {:stop, list(id())}

  @doc "Starts the engine, with options of its own."
  @callback start_link(opts :: Keyword.t()) :: GenServer.on_start()

  @doc "Loads the samples a song names, and returns the song with each loop's samples."
  @callback prepare(song :: %Mx.Song{}) :: %Mx.Song{}

  @doc "Loads a sample a loop named while playing, and sends the loop `{:sample_loaded, path, sample}`."
  @callback load_sample(path :: String.t(), loop :: pid()) :: :ok

  @doc "Starts an effect chain from a part's effects, and returns the chain its notes play into."
  @callback start_fx(effects :: list()) :: chain()

  @doc "Removes an effect chain after the Unix time in microseconds given, once its notes and tail have ended."
  @callback stop_fx(chain(), at_us :: integer()) :: :ok

  @doc "Starts, changes and stops the live audio inputs to match a version of the song."
  @callback set_live(lives :: list(), tempo :: number()) :: :ok

  @doc "Records `{:input, number}` of the sound card, or `{:sample, path}` played in its place, apart from the main output, to a WAV file from the Unix time in microseconds given."
  @callback record_input(
              path :: String.t(),
              source :: {:input, pos_integer()} | {:sample, String.t()},
              at_us :: integer()
            ) :: :ok | {:error, String.t()}

  @doc "Stops recording the input and closes its file."
  @callback stop_input() :: :ok | {:error, String.t()}

  @doc "The sample rate notes render offline at."
  @callback render_rate() :: pos_integer()

  @doc "Renders one note of a synth offline for some seconds, into a folder, with changes to it as `{seconds, params}`, and returns its left channel."
  @callback render_note(
              atom(),
              params(),
              seconds :: number(),
              dir :: String.t(),
              changes :: [{number(), params()}]
            ) :: [float()]

  @doc "Renders one note of a synth offline through effects, each `{effect, params}`, and returns `{left, right}`."
  @callback render_through(
              atom(),
              params(),
              seconds :: number(),
              dir :: String.t(),
              effects :: list()
            ) :: {[float()], [float()]}

  @doc "An id for a sound that a later event changes."
  @callback new_id() :: id()

  @doc "Plays events at the Unix time in microseconds given."
  @callback play(at_us :: integer(), events :: list(event())) :: :ok
end
