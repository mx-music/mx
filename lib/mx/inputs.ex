defmodule Mx.Inputs do
  @moduledoc """
  Keeps the latest value of every input from outside mx, and the values loops share.

  It listens to every MIDI input port connected when it starts, and for OSC on the port the song names with `osc_from`.
  It keeps the value of each MIDI controller by number, the velocity of each MIDI note by number, 0 once the note is off, and the arguments of each OSC address, whatever port or channel they came from.
  A loop's pass reads a snapshot of them all, so a pass reads one moment of the inputs from start to end.
  Each input is also sent to subscribers as `{:input, event}`, so the band can start the loops it triggers.

  A shared value is kept with the beat of the set step that set it, and the real time of that beat.
  A pass starting on a beat reads, for each name, the value the last set step before that beat left, so a set step on that beat reaches it only from its next pass on.
  Loops work out their passes ahead of time and in no fixed order, so each loop the band follows says how far it has worked out, and a pass's snapshot waits until every other followed loop has worked out up to its beat.
  The loop furthest behind never waits, so no two loops wait for each other; a snapshot waits no later than the time it is given, so a loop that hangs makes the others read without its values instead of stopping them.
  """

  use GenServer

  import Bitwise

  alias Mx.OSC

  @doc "Starts listening to the MIDI inputs, unless `midi: false`, under the name in `opts`, or `Mx.Inputs` unless `name: nil`."
  def start_link(opts) when is_list(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc "The latest value of every input, and each shared value as the set steps whose beat has come left it."
  def snapshot(inputs \\ __MODULE__) when is_pid(inputs) or is_atom(inputs) do
    GenServer.call(inputs, :snapshot)
  end

  @doc """
  Every input and shared value as a pass starting at `beat` reads them, as a map it reads from start to end.
  It waits until every other loop followed has worked out up to `beat`, or until the Unix time `until_us` in microseconds.
  """
  def snapshot_at(inputs \\ __MODULE__, beat, until_us)
      when (is_pid(inputs) or is_atom(inputs)) and is_number(beat) and is_integer(until_us) do
    wait_ms = div(max(until_us - Mx.Clock.now(), 0), 1000)
    GenServer.call(inputs, {:snapshot_at, beat, until_us}, wait_ms + 5000)
  end

  @doc "Shares a value under `name` with every loop from `beat` on, a set step's beat, which plays at the Unix time `at_us`."
  def put(inputs \\ __MODULE__, name, value, beat, at_us)
      when (is_pid(inputs) or is_atom(inputs)) and is_atom(name) and is_number(beat) and
             is_integer(at_us) do
    GenServer.cast(inputs, {:put, name, value, beat, at_us})
  end

  @doc "Follows the loop `pid`, which has handed over every set step before `beat`; nil stops following it, as does its exit."
  def worked_out(inputs \\ __MODULE__, pid, beat)
      when (is_pid(inputs) or is_atom(inputs)) and is_pid(pid) and
             (is_number(beat) or is_nil(beat)) do
    GenServer.call(inputs, {:worked_out, pid, beat})
  end

  @doc "Listens for OSC on a UDP port, as the song's `osc_from` asks."
  def listen(inputs \\ __MODULE__, port)
      when (is_pid(inputs) or is_atom(inputs)) and (is_integer(port) or is_nil(port)) do
    GenServer.cast(inputs, {:listen, port})
  end

  @doc "Sends each input that arrives to `pid` as `{:input, event}`."
  def subscribe(inputs \\ __MODULE__, pid)
      when (is_pid(inputs) or is_atom(inputs)) and is_pid(pid) do
    GenServer.cast(inputs, {:subscribe, pid})
  end

  @impl true
  def init(opts) when is_list(opts) do
    Process.flag(:trap_exit, true)
    inputs = self()

    # A port midiex cannot connect to stops its listener, which is trapped and leaves the other
    # ports listening.
    for port <- if(Keyword.get(opts, :midi, true), do: Midiex.ports(:input), else: []) do
      {:ok, listener} = Midiex.Listener.start_link(port: port)
      Midiex.Listener.add_handler(listener, fn msg -> send(inputs, {:midi_in, msg.data}) end)

      # The listener subscribes on a cast, so a call after it waits until it has.
      catch_exit(fn -> :sys.get_state(listener) end)
    end

    state = %{
      values: %{},
      shared: %{},
      loops: %{},
      waiting: [],
      subscribers: [],
      socket: nil,
      osc_port: nil
    }

    {:ok, open_osc(state, opts[:osc_port])}
  end

  @impl true
  def handle_call(:snapshot, {_, _}, %{} = state) do
    now = Mx.Clock.now()
    {:reply, values(state, fn {_, at_us} -> at_us <= now end), state}
  end

  def handle_call({:snapshot_at, beat, until_us}, {pid, _} = from, %{} = state) do
    if ready?(state, pid, beat) do
      {:reply, values_at(state, beat), state}
    else
      wait_ms = div(max(until_us - Mx.Clock.now(), 0), 1000)
      timer = Process.send_after(self(), {:give_up, from}, wait_ms)
      {:noreply, %{state | waiting: [{from, beat, timer} | state.waiting]}}
    end
  end

  def handle_call({:worked_out, pid, beat}, {_, _}, %{} = state) do
    state =
      case {state.loops[pid], beat} do
        {nil, nil} -> state
        {_, nil} -> forget(state, pid)
        {nil, _} -> put_in(state.loops[pid], {beat, Process.monitor(pid)})
        {{_, ref}, _} -> put_in(state.loops[pid], {beat, ref})
      end

    {:reply, :ok, state |> answer_ready() |> prune()}
  end

  @impl true
  def handle_cast({:put, name, value, beat, at_us}, %{} = state) do
    {later, earlier} = Enum.split_while(Map.get(state.shared, name, []), &(elem(&1, 0) > beat))
    {:noreply, put_in(state.shared[name], later ++ [{beat, value, at_us} | earlier])}
  end

  def handle_cast({:listen, port}, %{} = state), do: {:noreply, open_osc(state, port)}

  def handle_cast({:subscribe, pid}, %{} = state) do
    {:noreply, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_info({:midi_in, data}, %{} = state), do: {:noreply, midi(state, data)}

  def handle_info({:give_up, from}, %{} = state) do
    case List.keytake(state.waiting, from, 0) do
      {{^from, beat, _}, waiting} ->
        GenServer.reply(from, values_at(state, beat))
        {:noreply, %{state | waiting: waiting}}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, %{} = state) do
    {:noreply, state |> forget(pid) |> answer_ready() |> prune()}
  end

  def handle_info({:udp, socket, _, _, packet}, %{socket: socket} = state) do
    case OSC.decode(packet) do
      {address, args} when is_binary(address) ->
        event = {:osc, %{address: address, args: args}}
        {:noreply, state |> keep({:osc, address}, args) |> notify(event)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_message, %{} = state), do: {:noreply, state}

  defp midi(state, <<status, note, velocity>>) when status >>> 4 == 0x9 and velocity > 0 do
    event = {:midi_note, %{note: note, velocity: velocity}}
    state |> keep({:note, note}, velocity) |> notify(event)
  end

  defp midi(state, <<status, note, _>>) when (status >>> 4) in [0x8, 0x9] do
    keep(state, {:note, note}, 0)
  end

  defp midi(state, <<status, number, value>>) when status >>> 4 == 0xB do
    event = {:midi_cc, %{number: number, value: value}}
    state |> keep({:cc, number}, value) |> notify(event)
  end

  defp midi(state, _data), do: state

  defp ready?(state, pid, beat) do
    Enum.all?(state.loops, fn {loop, {worked_out, _}} -> loop == pid or worked_out >= beat end)
  end

  defp answer_ready(state) do
    {ready, waiting} =
      Enum.split_with(state.waiting, fn {{pid, _}, beat, _} -> ready?(state, pid, beat) end)

    for {from, beat, timer} <- ready do
      Process.cancel_timer(timer)
      GenServer.reply(from, values_at(state, beat))
    end

    %{state | waiting: waiting}
  end

  defp forget(state, pid) do
    case Map.pop(state.loops, pid) do
      {nil, _} ->
        state

      {{_, ref}, loops} ->
        Process.demonitor(ref, [:flush])
        %{state | loops: loops}
    end
  end

  defp values_at(state, beat), do: values(state, fn {set_beat, _} -> set_beat < beat end)

  defp values(state, before?) do
    Enum.reduce(state.shared, state.values, fn {name, sets}, values ->
      case Enum.find(sets, fn {beat, _, at_us} -> before?.({beat, at_us}) end) do
        {_, value, _} -> Map.put(values, {:value, name}, value)
        nil -> values
      end
    end)
  end

  # Keeps each value a snapshot may still read: those set from the earliest beat a followed loop
  # has not worked out, and the last before it that has played.
  defp prune(state) do
    earliest = state.loops |> Map.values() |> Enum.map(&elem(&1, 0)) |> Enum.min(fn -> nil end)
    now = Mx.Clock.now()

    shared =
      Map.new(state.shared, fn {name, sets} ->
        {later, earlier} =
          Enum.split_while(sets, fn {beat, _, at_us} ->
            (earliest != nil and beat >= earliest) or at_us > now
          end)

        {name, later ++ Enum.take(earlier, 1)}
      end)

    %{state | shared: shared}
  end

  defp catch_exit(fun) do
    fun.()
  catch
    :exit, _ -> :ok
  end

  defp keep(state, key, value), do: put_in(state.values[key], value)

  defp notify(state, event) do
    for pid <- state.subscribers, do: send(pid, {:input, event})
    state
  end

  defp open_osc(%{osc_port: port} = state, port), do: state

  defp open_osc(state, port) do
    if state.socket, do: :gen_udp.close(state.socket)

    case port && :gen_udp.open(port, [:binary, active: true]) do
      nil ->
        %{state | socket: nil, osc_port: nil}

      {:ok, socket} ->
        %{state | socket: socket, osc_port: port}

      {:error, reason} ->
        IO.puts(:stderr, "mx cannot listen for OSC on port #{port}: #{reason}")
        %{state | socket: nil, osc_port: nil}
    end
  end
end
