defmodule Mx.Bench do
  @moduledoc """
  Measures how a song plays, for `mix mx.bench`: whether its notes reach the engine in time, what a save costs while it plays, and how much of each buffer filling it takes.

  Every measurement plays against an offline engine, so nothing sounds and no sound card is needed.
  A measurement returns its rows, to print, and its figures, a map from a name such as `"lead/idle/least_lead_ms"` to a number, to keep in a file and compare a later run with.
  The lead of a note is the time between its being handed to the engine and its beat.
  """

  alias Mx.{Band, Clock, Inputs, Out, Page, Song, Watcher}
  alias Mx.Engine.Mxs

  @tick_ms 33
  @frames 512
  @band Mx.Bench.Band

  @doc """
  Plays the song at `path` for `seconds` under each of four loads: an idle machine, every scheduler of the VM busy, the song loaded and laid out every 300 ms, and twice as many busy OS processes as schedulers.
  Returns `{:ok, rows, figures}`, each row a map with `:load`, `:calls`, `:late`, `:least_lead_ms`, `:least_later_lead_ms`, the least lead of the notes of a part's second pass on, `:longest_call_ms` and `:held_ms`, the longest a process handing notes over kept a normal scheduler of the VM without a break, 0 when under a millisecond, or `{:error, message}`.
  """
  def lead(path, seconds) when is_binary(path) and is_number(seconds) do
    with {:ok, song} <- Song.load(path) do
      cores = System.schedulers_online()

      loads = [
        {"idle", fn -> :ok end, fn _ -> :ok end},
        {"vm_busy", fn -> Enum.map(1..cores, fn _ -> spawn(&spin/0) end) end, &kill/1},
        {"saves", fn -> [spawn(fn -> reload(path) end)] end, &kill/1},
        {"os_busy", fn -> Enum.map(1..(cores * 2), fn _ -> yes() end) end, &kill_os/1}
      ]

      rows =
        for {name, load, unload} <- loads do
          loaded = load.()
          Process.sleep(500)
          calls = played(song, seconds)
          unload.(loaded)
          Process.sleep(500)
          lead_row(name, calls)
        end

      figures =
        for row <- rows,
            key <- [:late, :least_lead_ms, :least_later_lead_ms, :longest_call_ms, :held_ms],
            into: %{} do
          {"lead/#{row.load}/#{key}", row[key]}
        end

      {:ok, rows, figures}
    end
  end

  defp lead_row(name, {calls, later, held_ms}) do
    %{
      load: name,
      held_ms: held_ms,
      calls: length(calls),
      late: Enum.count(calls, fn {lead, _took} -> lead < 0 end),
      least_lead_ms: calls |> Enum.map(&elem(&1, 0)) |> Enum.min(fn -> 0 end) |> ms(),
      least_later_lead_ms: later |> Enum.min(fn -> 0 end) |> ms(),
      longest_call_ms: calls |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end) |> ms()
    }
  end

  # Each call's lead and length in microseconds, and the longest a caller held a scheduler.
  defp played(song, seconds) do
    table = :ets.new(:bench, [:public, :duplicate_bag])

    children = [
      Supervisor.child_spec({Mxs, [live: false]}, shutdown: 10_000),
      {Inputs, name: nil, midi: false},
      {Band,
       name: @band,
       song: song,
       play: timed(table, fn -> 0 end),
       new_id: &Mxs.new_id/0,
       start_fx: &Mxs.start_fx/1,
       stop_fx: &Mxs.stop_fx/2,
       start_part: &Mxs.start_part(&1, &2, beats: true),
       hand: handed(table),
       place_beats: &Mxs.place_beats/1,
       set_tempo: &Mxs.set_tempo/2}
    ]

    monitor = spawn(fn -> held(table) end)
    before = :erlang.system_monitor(monitor, [{:long_schedule, 1}])
    {:ok, session} = Supervisor.start_link(children, strategy: :rest_for_one)
    # The engine renders, unheard, as the sound card would, so it says when each pass ends.
    renderer = spawn_link(&render/0)
    Process.sleep(round(seconds * 1000))
    Process.unlink(renderer)
    Process.exit(renderer, :kill)
    Supervisor.stop(session)
    :erlang.system_monitor(before)
    Process.exit(monitor, :kill)
    rows = :ets.tab2list(table)
    :ets.delete(table)
    callers = for {:caller, pid} <- rows, into: MapSet.new(), do: pid
    held = for {:held, pid, held_ms} <- rows, pid in callers, do: held_ms
    calls = for {:play, _at, lead, took} <- rows, do: {lead, took}
    later = for {:later, lead} <- rows, do: lead
    {calls, later, Enum.max(held, fn -> 0 end)}
  end

  # The VM says when a process kept a normal scheduler for a millisecond or more without a break.
  defp held(table) do
    receive do
      {:monitor, pid, :long_schedule, info} when is_pid(pid) ->
        :ets.insert(table, {:held, pid, info[:timeout]})

      _other ->
        :ok
    end

    held(table)
  end

  defp timed(table, at) do
    fn at_us, events ->
      before = System.os_time(:microsecond)
      Mxs.play(at_us, events)
      :ets.insert(table, {:play, at.(), at_us - before, System.os_time(:microsecond) - before})
      :ets.insert(table, {:caller, self()})
      :ok
    end
  end

  # Each note of a pass is timed from the call that hands it over to its beat.
  defp handed(table) do
    fn name, span, label, events, opts ->
      before = System.os_time(:microsecond)
      Mxs.pass(name, span, label, events, opts)
      took = System.os_time(:microsecond) - before
      timeline = Band.timeline(@band)

      for {beat, _event} <- events do
        lead = Band.time_at(timeline, beat) - before
        :ets.insert(table, {:play, 0, lead, took})
        if label > 0, do: :ets.insert(table, {:later, lead})
      end

      :ets.insert(table, {:caller, self()})
      :ok
    end
  end

  defp render do
    Mxs.render_to(System.os_time(:microsecond))
    Process.sleep(10)
    render()
  end

  defp spin, do: spin()

  defp reload(path) do
    with {:ok, song} <- Song.load(path), do: Page.data(song, path, 30)
    Process.sleep(300)
    reload(path)
  end

  defp yes do
    port = Port.open({:spawn, "yes"}, [:binary, {:line, 1}])
    {:os_pid, pid} = Port.info(port, :os_pid)
    Port.connect(port, spawn(fn -> drain(port) end))
    pid
  end

  defp drain(port) do
    receive do
      {^port, _line} -> drain(port)
    end
  end

  defp kill(pids), do: Enum.each(pids, &Process.exit(&1, :kill))
  defp kill_os(pids), do: Enum.each(pids, &System.cmd("kill", ["-9", to_string(&1)]))

  @doc """
  Plays a copy of the song at `path` for `seconds` as a session does, saves a change to the copy at each of `saves`, seconds from the start, and is sent each saved version mx loads as Mx Studio is, in the process that sends its beat every #{@tick_ms} ms.
  Returns `{:ok, rows, loads, figures}`: a row for each second, a map with `:second`, `:notes`, `:late`, `:longest_gap_ms`, `:memory_mb` and `:processes`, how many times mx loaded the saves, and for each save the milliseconds until its description reached that process.
  The song's own file is not changed.
  """
  def saves(path, seconds, saves)
      when is_binary(path) and is_integer(seconds) and is_list(saves) do
    dir = Path.join(System.tmp_dir!(), "mx-bench-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    copy = Path.join(dir, Path.basename(path))
    File.cp!(path, copy)

    try do
      with {:ok, song} <- Song.load(copy), do: saved(song, copy, seconds, saves)
    after
      File.rm_rf!(dir)
    end
  end

  defp saved(song, path, seconds, saves) do
    table = :ets.new(:bench, [:public, :duplicate_bag])
    started = now()
    at = fn -> now() - started end

    switch = fn song ->
      :ets.insert(table, {:load, at.(), nil})
      Inputs.listen(song.osc_from)
      Band.switch(Band, song)
    end

    children = [
      Supervisor.child_spec({Mxs, [live: false]}, shutdown: 10_000),
      Out,
      {Inputs, osc_port: song.osc_from, midi: false},
      {Band,
       name: Band,
       song: song,
       play: timed(table, at),
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
       live: &Mxs.set_live/2},
      {Watcher, path: path, song: song, on_song: switch}
    ]

    {:ok, session} = Supervisor.start_link(children, strategy: :rest_for_one)
    window = spawn_link(fn -> window(table, at, session, now()) end)
    send(window, :subscribe)
    sampler = spawn_link(fn -> sample(table, at) end)

    for {save_at, index} <- Enum.with_index(saves) do
      wait_until(at, save_at)
      File.write!(path, File.read!(path) <> "\n# saved #{index}\n")
      :ets.insert(table, {:saved, at.()})
    end

    wait_until(at, seconds)
    Enum.each([window, sampler], &Process.unlink/1)
    Enum.each([window, sampler], &Process.exit(&1, :kill))
    rows = :ets.tab2list(table)
    :ets.delete(table)
    Supervisor.stop(session)
    save_report(rows, seconds, length(saves))
  end

  defp wait_until(at, second) do
    Process.sleep(max(0, div(round(second * 1_000_000) - at.(), 1000)))
  end

  # One process sends the beat and is sent each saved version mx loads, as Mx Studio's is.
  defp window(table, at, session, due) do
    receive do
      :subscribe ->
        {Watcher, watcher, _, _} = List.keyfind(Supervisor.which_children(session), Watcher, 0)
        Watcher.subscribe(watcher)
        window(table, at, session, due)

      {:mx_loaded, _number, _description} ->
        :ets.insert(table, {:described, at.()})
        window(table, at, session, due)
    after
      max(0, div(due - now(), 1000)) ->
        Band |> Band.timeline() |> Band.beat_at(Clock.now())
        :ets.insert(table, {:beat, at.()})
        window(table, at, session, max(due + @tick_ms * 1000, now()))
    end
  end

  defp sample(table, at) do
    memory = :erlang.memory(:total) / 1_048_576
    :ets.insert(table, {:vm, at.(), memory, :erlang.system_info(:process_count)})
    Process.sleep(250)
    sample(table, at)
  end

  defp save_report(rows, seconds, saves) do
    second = fn row -> div(elem(row, 1), 1_000_000) end
    plays = for {:play, _, _, _} = row <- rows, do: row
    beats = rows |> Enum.filter(&match?({:beat, _}, &1)) |> Enum.map(&elem(&1, 1)) |> Enum.sort()

    gaps =
      beats
      |> Enum.zip(tl(beats ++ [List.last(beats) || 0]))
      |> Enum.map(fn {a, b} -> {a, b - a} end)

    sampled = for {:vm, _, _, _} = row <- rows, do: row
    loads = Enum.count(rows, &match?({:load, _, nil}, &1))
    saved = for {:saved, at} <- Enum.sort(rows), do: at
    described = for {:described, at} <- Enum.sort(rows), do: at

    waits =
      for at <- saved, shown = Enum.find(described, &(&1 >= at)), shown != nil, do: ms(shown - at)

    table =
      for index <- 0..(seconds - 1) do
        here = Enum.filter(plays, &(second.(&1) == index))
        seen = Enum.filter(sampled, &(second.(&1) == index))

        %{
          second: index,
          notes: length(here),
          late: Enum.count(here, &(elem(&1, 2) < 0)),
          longest_gap_ms:
            gaps
            |> Enum.filter(fn {at, _} -> div(at, 1_000_000) == index end)
            |> Enum.map(&elem(&1, 1))
            |> Enum.max(fn -> 0 end)
            |> ms(),
          memory_mb: seen |> Enum.map(&elem(&1, 2)) |> Enum.max(fn -> 0.0 end) |> Float.round(1),
          processes: seen |> Enum.map(&elem(&1, 3)) |> Enum.max(fn -> 0 end)
        }
      end

    figures = %{
      "saves/late" => Enum.count(plays, &(elem(&1, 2) < 0)),
      "saves/longest_gap_ms" => table |> Enum.map(& &1.longest_gap_ms) |> Enum.max(fn -> 0 end),
      "saves/loads_per_save" => if(saves == 0, do: 0, else: loads / saves),
      "saves/longest_wait_ms" => Enum.max(waits, fn -> 0 end)
    }

    {:ok, table, %{by_mx: loads, described_after_ms: waits}, figures}
  end

  @doc """
  Renders `seconds` of each song in `paths`, a buffer of #{@frames} frames at a time, and times the engine filling each buffer.
  Returns `{:ok, rows, figures}`, each row a map with `:song`, `:buffers`, `:mean_percent` and `:worst_percent`, the time filling took as a share of the time a buffer lasts, and `:over`, how many took longer than they last.
  """
  def buffers(paths, seconds) when is_list(paths) and is_number(seconds) do
    rows = Enum.map(paths, &filled(&1, seconds))

    case Enum.find(rows, &match?({:error, _}, &1)) do
      nil ->
        figures =
          for row <- rows, key <- [:mean_percent, :worst_percent, :over], into: %{} do
            {"buffers/#{row.song}/#{key}", row[key]}
          end

        {:ok, rows, figures}

      error ->
        error
    end
  end

  defp filled(path, seconds) do
    with {:ok, song} <- Song.load(path) do
      song = %{song | loops: Enum.filter(song.loops, &(&1.on == nil))}
      step_us = round(@frames / Mxs.render_rate() * 1_000_000)
      steps = round(seconds * 1_000_000 / step_us)
      Clock.start_render(0)
      {:ok, engine} = Mxs.start_link(live: false, fade_ms: 0)
      {:ok, inputs} = Inputs.start_link(name: nil, midi: false)

      {:ok, band} =
        Band.start_link(
          song: song,
          start_us: 0,
          play: &Mxs.play/2,
          new_id: &Mxs.new_id/0,
          prepare: &Mxs.prepare/1,
          load_sample: &Mxs.load_sample/2,
          start_fx: &Mxs.start_fx/1,
          stop_fx: &Mxs.stop_fx/2,
          inputs: &Inputs.snapshot_at(inputs, &1, &2),
          set: &Inputs.put(inputs, &1, &2, &3, &4),
          worked_out: &Inputs.worked_out(inputs, &1, &2)
        )

      costs =
        for step <- 1..steps do
          band |> Band.loops() |> Enum.each(&tick/1)
          {us, _sounding} = :timer.tc(fn -> Mxs.render_to(step * step_us) end)
          Clock.advance(step * step_us)
          us
        end

      Enum.each([band, inputs, engine], &GenServer.stop/1)
      Clock.stop_render()
      percent = fn us -> Float.round(us / step_us * 100, 1) end

      %{
        song: Path.basename(path),
        buffers: steps,
        mean_percent: percent.(Enum.sum(costs) / steps),
        worst_percent: percent.(Enum.max(costs)),
        over: Enum.count(costs, &(&1 > step_us))
      }
    end
  end

  defp tick(loop) do
    send(loop, :tick)
    :sys.get_state(loop)
  catch
    :exit, _reason -> :ok
  end

  @doc "Writes `figures` to the file at `path`, one `name value` to a line, sorted by name."
  def write(path, figures) when is_binary(path) and is_map(figures) do
    lines = for {name, value} <- Enum.sort(figures), do: "#{name} #{value}\n"
    File.write!(path, lines)
  end

  @doc "The figures in the file at `path`, as `write/2` wrote them, or `{:error, message}`."
  def read(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        figures =
          for line <- String.split(content, "\n", trim: true), into: %{} do
            [name, value] = String.split(line, " ")
            {number, ""} = Float.parse(value)
            {name, number}
          end

        {:ok, figures}

      {:error, reason} ->
        {:error, "cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  The figures of `now` that are worse than in `before` by more than a tenth, as `{name, before, now}`, sorted by name.
  A lead is worse when it is shorter, and every other figure when it is larger; a figure that was 0 is worse once it is above 0, and a figure in only one of the two is left out.
  """
  def worse(before, now) when is_map(before) and is_map(now) do
    for {name, value} <- Enum.sort(now),
        was = before[name],
        was != nil,
        worse?(name, was, value) do
      {name, was, value}
    end
  end

  defp worse?(name, was, value) do
    if String.ends_with?(name, "least_lead_ms"), do: value < was * 0.9, else: value > was * 1.1
  end

  defp ms(us), do: Float.round(us / 1000, 1)
  defp now, do: System.monotonic_time(:microsecond)
end
