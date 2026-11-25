defmodule Mx.Out do
  @moduledoc """
  Sends MIDI and OSC to other devices and programs at their time.

  These have no timestamps, so loops hand each message here ahead of time, and it is sent at the moment.
  The process wakes 2 ms before a message is due and waits out the rest by reading the clock, which keeps messages within a millisecond of their time; Erlang timers alone run 1 to 7 ms late.

  A MIDI message goes to the output port it names, or to every connected output port when it names none.
  A port that is not connected, or an OSC destination that cannot be reached, prints one warning naming it, and its messages are dropped.
  On stop it sends note off for every MIDI note still sounding.
  """

  use GenServer

  import Bitwise

  @early_us 2000

  @doc "Starts the sender, under the name in `opts`, or `Mx.Out` unless `name: nil`."
  def start_link(opts) when is_list(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, if(name, do: [name: name], else: []))
  end

  @doc "Sends a `{:midi, port, bytes}` or `{:osc, {host, port}, packet}` message at a Unix time in microseconds."
  def schedule(out \\ __MODULE__, at_us, message)
      when (is_pid(out) or is_atom(out)) and is_integer(at_us) and is_tuple(message) do
    GenServer.cast(out, {:schedule, at_us, message})
  end

  @impl true
  def init(opts) when is_list(opts) do
    Process.flag(:trap_exit, true)
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])

    # The first port listing starts CoreMIDI and takes most of a second, so it happens before any
    # message is due.
    Midiex.ports(:output)

    state = %{
      queue: [],
      seq: 0,
      timer: nil,
      socket: socket,
      conns: %{},
      hosts: %{},
      warned: MapSet.new(),
      sounding: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:schedule, at_us, message}, %{} = state) do
    state = resolve(state, message)
    item = {at_us, state.seq, message}
    queue = :lists.merge([item], state.queue)
    {:noreply, arm(%{state | queue: queue, seq: state.seq + 1})}
  end

  @impl true
  def handle_info(:wake, %{} = state), do: {:noreply, state |> send_due() |> arm()}

  def handle_info({:EXIT, _, _}, %{} = state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{} = state) do
    Enum.reduce(state.sounding, state, fn {port, channel, note}, state ->
      deliver(state, {:midi, port, <<0x80 ||| channel, note, 0>>})
    end)
  end

  defp send_due(%{queue: [{at_us, _, message} | rest]} = state) do
    if at_us <= now() + @early_us do
      spin(at_us)
      state = deliver(%{state | queue: rest}, message)
      send_due(state)
    else
      state
    end
  end

  defp send_due(state), do: state

  defp spin(at_us), do: if(now() < at_us, do: spin(at_us), else: :ok)

  defp arm(state) do
    if state.timer, do: Process.cancel_timer(state.timer)

    case state.queue do
      [] ->
        %{state | timer: nil}

      [{at_us, _, _} | _] ->
        delay_ms = max(0, div(at_us - @early_us - now(), 1000))
        %{state | timer: Process.send_after(self(), :wake, delay_ms)}
    end
  end

  # Looks a host up when its message is scheduled, ahead of time, so a slow lookup never delays a
  # send.
  defp resolve(state, {:osc, {host, _port}, _packet}) when not is_map_key(state.hosts, host) do
    put_in(state.hosts[host], :inet.getaddr(to_charlist(host), :inet))
  end

  defp resolve(state, _message), do: state

  defp deliver(state, {:osc, {host, port}, packet}) do
    result =
      with {:ok, address} <- state.hosts[host],
           do: :gen_udp.send(state.socket, address, port, packet)

    case result do
      :ok ->
        state

      {:error, reason} ->
        warn_once(state, {:osc, host, port}, "cannot send OSC to #{host}:#{port}: #{reason}")
    end
  end

  defp deliver(state, {:midi, port, bytes}) do
    {state, conns} = connections(state, port)

    state =
      if conns == [] and port != nil do
        warn_once(
          state,
          {:midi, port},
          "MIDI port #{port} is not connected, so its messages are dropped."
        )
      else
        state
      end

    for conn <- conns, do: Midiex.send_msg(conn, bytes)
    track(state, port, bytes)
  end

  defp connections(state, nil) do
    ports = Midiex.ports(:output)

    Enum.reduce(ports, {state, []}, fn port, {state, conns} ->
      {state, named} = connections(state, port.name)
      {state, conns ++ named}
    end)
  end

  defp connections(state, name) do
    case Map.fetch(state.conns, name) do
      {:ok, conn} ->
        {state, [conn]}

      :error ->
        case :output |> Midiex.ports() |> Enum.find(&(&1.name == name)) do
          nil ->
            {state, []}

          port ->
            conn = Midiex.open(port)
            {put_in(state.conns[name], conn), [conn]}
        end
    end
  end

  defp track(state, port, <<status, note, velocity>>) when status >>> 4 == 0x9 and velocity > 0 do
    %{state | sounding: MapSet.put(state.sounding, {port, status &&& 0x0F, note})}
  end

  defp track(state, port, <<status, note, _>>) when (status >>> 4) in [0x8, 0x9] do
    %{state | sounding: MapSet.delete(state.sounding, {port, status &&& 0x0F, note})}
  end

  defp track(state, _port, _bytes), do: state

  defp warn_once(state, key, message) do
    if key in state.warned do
      state
    else
      IO.puts(:stderr, message)
      %{state | warned: MapSet.put(state.warned, key)}
    end
  end

  defp now, do: System.os_time(:microsecond)
end
