defmodule Mx.Session do
  @moduledoc """
  Plays one song file: the engine, the band, and the
  watcher that hands each saved version to the band.

  Stopping the session stops them in reverse order, so the engine
  stops last and silences every note the band started.
  """

  use Supervisor

  alias Mx.{Band, Inputs, Out, Watcher}
  alias Mx.Engine.Mxs

  @doc """
  Starts playing the song in `opts` through the engine, from the beat `:from` if given, watching its file for changes.

  With `watch: false` and `source:` the song's text, it plays a song that has no file, such as one `Mx.Import.load/2` gives, and reads and watches no file.
  """
  def start_link(opts) when is_list(opts), do: Supervisor.start_link(__MODULE__, opts)

  @doc """
  Subscribes the calling process to the saves of the session's song, and returns the version loaded now.

  It is sent each save that loads and each that does not, as `Mx.Watcher.subscribe/1` describes, and when each part takes a version over, as `Mx.Band.subscribe/1` describes.
  """
  def subscribe(session) when is_pid(session) do
    :ok = Band.subscribe(band(session))
    Watcher.subscribe(watcher(session))
  end

  @doc "The version of the session's song loaded now, as `{number, description}`, without reading its file, as `Mx.Watcher.description/1` gives it."
  def description(session) when is_pid(session), do: Watcher.description(watcher(session))

  @doc "Sends the calling process where the beat of the session's song is, as `{:mx_beat, message}`, now and whenever the tempo or the output's delay changes; `Mx.Beat` says what a message holds and how to work out the beat from it."
  def follow_beat(session) when is_pid(session), do: Band.follow(band(session))

  @doc """
  Mutes the part `name` of the session's song, or lets it be heard again with `muted` false.

  The part goes silent at once, the notes it has already sent included, and plays on unheard, so it comes back in time.
  It stays muted while the session plays, through every save of the song's file, and nothing is written to the file.
  A name the song has no part of is refused with `{:error, message}`.
  """
  def mute(session, name, muted \\ true) when is_pid(session) and is_boolean(muted) do
    Band.mute(band(session), name, muted)
  end

  @doc """
  Solos the parts named, so only they are heard, in place of the parts soloed before; with none named every part is heard again.

  A soloed part that is also muted stays silent.
  Solo lasts as `mute/3` does, and a name the song has no part of is refused with `{:error, message}`.
  """
  def solo(session, names) when is_pid(session) and is_list(names) do
    Band.solo(band(session), names)
  end

  @doc """
  Plays the session's song at `share` of its own tempo, heard within 200 ms on every part at once, or moving there evenly over `over` beats.

  Every tempo the song gives is played times the share, its own and those its music writes, through every save of the song's file, and nothing is written to the file; 1 plays the song's own tempo.
  A share outside 0.25 to 4 is refused with `{:error, message}`.
  """
  def scale_tempo(session, share, over \\ 0) when is_pid(session) do
    Band.scale_tempo(band(session), share, over)
  end

  @doc """
  Takes the version of the song saved last over now, from the first whole beat 150 ms away, and returns `{:ok, beat}`.

  Each part the version changes ends the pass that sounds then and plays the version's pass from that beat of its music, so the parts stay together, and each part it removes stops there.
  """
  def take_over_now(session) when is_pid(session), do: Band.take_over_now(band(session))

  @doc """
  Plays the part `name` with another synth, `synth: :clarinet`, or other options of its synth, such as `vel: 0.8`, heard from its next note within a bar, while the file stays as it is.

  What is tried adds to what was tried on the part before, and lasts while the session plays, through every save of the song's file, until `stop_trying/2`.
  The part keeps its notes, its other options and its effects; an option the song gives that the tried synth does not take is left out, and named on standard error.
  A part, synth or option that does not exist is refused with `{:error, message}`.
  """
  def try_part(session, name, tried) when is_pid(session) and is_list(tried) do
    Band.try_part(band(session), name, tried)
  end

  @doc """
  Plays the recording `ref`, a path or a sample's name, on the part `name` from the first whole beat more than 150 ms away, through the part's effects and at its place in the mix, while the part plays on, and returns `{:ok, beat}`.

  It takes a sample's options, `from:` and `to:` in seconds and `amp:` among them, and nothing is written to the song's file.
  It plays through saves of the file, mutes with the part, and stops when another recording plays on the part or `stop_recording/2` stops it.
  A part the song does not have, a file that cannot play and a range outside the recording are refused with `{:error, message}`.
  `Mx.Engine.Mxs.play_recording/2` plays one with no song.
  """
  def play_recording(session, name, ref, opts \\ []) when is_pid(session) and is_list(opts) do
    with {:ok, path} <- Mx.Samples.check(ref, opts),
         {:ok, sample} <- Mxs.sample(path) do
      Band.play_recording(band(session), name, sample, opts)
    end
  end

  @doc "Stops the recording `play_recording/4` plays on the part `name`, within 150 ms, while the part and the song go on."
  def stop_recording(session, name) when is_pid(session),
    do: Band.stop_recording(band(session), name)

  @doc "Plays the part `name` as the song gives it again, from its next note within a bar."
  def stop_trying(session, name) when is_pid(session), do: Band.stop_trying(band(session), name)

  defp band(session) do
    {Band, pid, _type, _modules} = List.keyfind(Supervisor.which_children(session), Band, 0)
    pid
  end

  defp watcher(session) do
    {Watcher, pid, _type, _modules} = List.keyfind(Supervisor.which_children(session), Watcher, 0)
    pid
  end

  @impl true
  def init(opts) when is_list(opts) do
    song = Keyword.fetch!(opts, :song)
    synth_opts = Keyword.take(opts, [:record]) ++ [input: song.live != []]

    children = [
      Supervisor.child_spec({Mxs, synth_opts}, shutdown: 10_000),
      Out,
      {Inputs, osc_port: song.osc_from},
      {Band,
       name: Band,
       song: song,
       play: &Mxs.play/2,
       new_id: &Mxs.new_id/0,
       prepare: &Mxs.prepare/1,
       load_sample: &Mxs.load_sample/2,
       start_fx: &Mxs.start_fx/1,
       stop_fx: &Mxs.stop_fx/2,
       start_part: &Mxs.start_part(&1, &2, beats: true),
       hand: &Mxs.pass/5,
       cut: &Mxs.cut/2,
       place_beats: &Mxs.place_beats/1,
       set_tempo: &Mxs.set_tempo/2,
       mute: &Mxs.mute/2,
       solo: &Mxs.solo/2,
       out: &Out.schedule/2,
       inputs: &Inputs.snapshot_at/2,
       set: &Inputs.put/4,
       worked_out: &Inputs.worked_out/2,
       subscribe: &Inputs.subscribe/1,
       live: &Mxs.set_live/2,
       delay: &Mxs.delay/1,
       on_end: Keyword.get(opts, :on_end, fn -> :ok end),
       from: Keyword.get(opts, :from, 0),
       share: Keyword.get(opts, :share, 1)},
      {Watcher,
       [path: Keyword.fetch!(opts, :path), song: song, on_song: &switch/1] ++
         Keyword.take(opts, [:watch, :source])}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp switch(song) do
    Inputs.listen(song.osc_from)
    Band.switch(Band, song)
  end
end
