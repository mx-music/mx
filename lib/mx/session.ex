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

  @doc "Starts playing the song in `opts` through the engine, from the beat `:from` if given, watching its file for changes."
  def start_link(opts) when is_list(opts), do: Supervisor.start_link(__MODULE__, opts)

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
       out: &Out.schedule/2,
       inputs: &Inputs.snapshot_at/2,
       set: &Inputs.put/4,
       worked_out: &Inputs.worked_out/2,
       subscribe: &Inputs.subscribe/1,
       live: &Mxs.set_live/2,
       on_end: Keyword.get(opts, :on_end, fn -> :ok end),
       from: Keyword.get(opts, :from, 0)},
      {Watcher, path: Keyword.fetch!(opts, :path), on_song: &switch/1}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp switch(song) do
    Inputs.listen(song.osc_from)
    Band.switch(Band, song)
  end
end
