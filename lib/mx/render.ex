defmodule Mx.Render do
  @moduledoc """
  Renders a song file offline to a stereo WAV file, as fast as the machine renders it and with no sound card, for `--render`.

  The band, its loops and an offline engine work out the song as they do when it plays, against `Mx.Clock`'s time, which the render moves on to the next time a loop needs to work something out, 10 ms at least.
  At each step every loop is ticked in turn by name and waited for, so its passes reach the engine in the same order on every run, and the engine renders up to that time.
  The render starts at the song's first beat, and ends once its music has ended or `seconds:` have passed, and the notes still sounding have faded, for four seconds at most.
  With `ring_out: false` it leaves that ring out, so the file ends where the music ends.
  With `mute:` it leaves out the parts named, and with `solo:` it hears only those parts, as `Mx.Session.mute/3` and `Mx.Session.solo/2` do while a song plays.
  With `ring_out: true` it keeps the ring for as long as the effects ring after those notes have faded, as `ring_out/2` gives it.
  Without `ring_out:` the render ends as those notes fade, and says which part's effect it cuts short and how long it would ring.
  MIDI and OSC are not sent, and a loop that waits for input plays nothing; each part left out is named once, a part that sends MIDI or OSC the first time it does.

  While it renders it prints a line such as `rendered 37.5 of 148.2 seconds` about four times a second, and once more when the music has rendered, giving the seconds of music rendered and the seconds it renders in all, until the music ends or for `seconds:`, the fade after it left out.
  """

  alias Mx.{Band, Clock, Inputs, Loudness, Pass, Recording, Song, Tempo}
  alias Mx.Engine.Mxs

  @ahead_us 500_000
  @step_us 10_000
  @fade_us 4_000_000
  @progress_ms 250

  @doc "Renders the song at `path` to the WAV file `out`, with `seconds:`, `force:`, `ring_out:`, `mute:`, `solo:`, `loudness:`, the loudness in LUFS to scale the finished file to, no further than a peak of -1 dB, and `share:`, the share of its tempo to play it at, 1 unless given, and returns `:ok` once written, or `{:error, message}`; the process given as `follow:` is sent where the beat is, as `Mx.Beat` describes, in the render's own time."
  def render(path, out, opts) when is_binary(path) and is_binary(out) and is_list(opts) do
    seconds = opts[:seconds]
    share = Keyword.get(opts, :share, 1)
    ring_out = opts[:ring_out]

    with :ok <- Band.check_share(share),
         :ok <- check_ring_out(ring_out),
         :ok <- check_loudness(opts[:loudness]),
         :ok <- Recording.check(out, Keyword.get(opts, :force, false)),
         {:ok, _apps} <- Application.ensure_all_started(:mx),
         {:ok, song} <- load(path, opts),
         :ok <- check(song, seconds),
         :ok <- check_parts(song, opts),
         playing = %{song | loops: Enum.filter(song.loops, &(&1.on == nil))},
         {:ok, total} <- total(playing, seconds, share),
         {:ok, ring} <- ring(playing, seconds, share) do
      Enum.each(left_out(song), &IO.puts/1)
      follow = List.wrap(opts[:follow])
      heard = Keyword.take(opts, [:mute, :solo])

      with :ok <- run(playing, out, seconds, follow, share, total, {ring_out, ring}, heard) do
        if (ring_out == nil and ring) && ring.seconds >= 0.05 do
          IO.puts(cut_short(ring, playing))
        end

        loudness = settle(out, opts[:loudness])
        out |> Recording.report(loudness) |> Enum.each(&IO.puts/1)
      end
    end
  end

  defp check_parts(song, opts) do
    names = Enum.map(song.loops, &Atom.to_string(&1.name))
    chosen = Keyword.get(opts, :mute, []) ++ Keyword.get(opts, :solo, [])
    asked = Enum.map(chosen, &to_string/1)

    case Enum.find(asked, &(&1 not in names)) do
      nil -> :ok
      unknown -> {:error, "the song has no part named #{unknown}"}
    end
  end

  # A score renders as the song mx import would write from it, without writing it.
  defp load(path, opts) do
    if Mx.Import.score?(path) do
      with {:ok, song, imported} <-
             Mx.Import.load(path, Keyword.take(opts, [:part, :tempo, :grid, :tune])) do
        Enum.each(imported.left_out, &IO.puts/1)
        {:ok, song}
      end
    else
      Song.load(path)
    end
  end

  @doc """
  How long a song's effects ring once its notes have faded, rendered for `seconds:` and at `share:` of its tempo as `render/3` takes them, as `{:ok, %{seconds: seconds, part: part, effect: effect}}` naming the effect that rings longest among those that ring longest together and its part, a bus's name for an effect of a bus and `:song` for one of the song's own effects, `{:ok, nil}` when no effect rings, or `{:error, message}`.

  A part's effects ring for as long as each of them rings in turn, then those of the buses it sends into, and then each of the song's own, from its options, and an option given in beats lasts those beats at the tempo the music ends at.
  """
  def ring_out(%Song{} = song, opts \\ []) when is_list(opts) do
    playing = %{song | loops: Enum.filter(song.loops, &(&1.on == nil))}
    ring(playing, opts[:seconds], Keyword.get(opts, :share, 1))
  end

  defp ring(song, seconds, share) do
    with {:ok, bpm} <- end_tempo(song, seconds),
         {:ok, main} <- chain_rings(:song, song.fx, bpm * share),
         {:ok, buses} <- map_ok(song.buses, &chain_rings(&1.name, &1.fx, bpm * share)) do
      buses = song.buses |> Enum.map(& &1.name) |> Enum.zip(buses) |> Map.new()
      sends = Map.new(song.buses, &{&1.name, Keyword.keys(&1.send)})

      song.loops
      |> map_ok(fn loop ->
        with {:ok, own} <- chain_rings(loop.name, loop.fx, bpm * share) do
          rings = own ++ sent_rings(Keyword.keys(loop.send), buses, sends) ++ main
          {:ok, {loop.name, Enum.sum_by(rings, &elem(&1, 2)), rings}}
        end
      end)
      |> then(
        &with {:ok, rings} <- &1,
              do:
                {:ok,
                 [
                   {:song, Enum.sum_by(main, fn {_, _, tail} -> tail end), main}
                   | rings
                 ]}
      )
      |> longest_ring()
    end
  end

  # Each effect of a chain with whose it is and how long it rings.
  defp chain_rings(owner, fx, bpm) do
    with {:ok, tails} <- Mxs.effect_tails(fx, bpm) do
      rings =
        fx
        |> Keyword.keys()
        |> Enum.zip(tails)
        |> Enum.map(fn {effect, tail} -> {owner, effect, tail} end)

      {:ok, rings}
    end
  end

  # The effects of the buses that ring longest one after another, from the buses sent into on
  # through those they send into.
  defp sent_rings(names, buses, sends) do
    names
    |> Enum.map(fn name -> buses[name] ++ sent_rings(sends[name], buses, sends) end)
    |> Enum.max_by(fn rings -> Enum.sum_by(rings, &elem(&1, 2)) end, fn -> [] end)
  end

  defp longest_ring({:ok, rings}) do
    case Enum.filter(rings, fn {_part, seconds, _rings} -> seconds > 0 end) do
      [] ->
        {:ok, nil}

      ringing ->
        {_part, seconds, rings} = Enum.max_by(ringing, &elem(&1, 1), fn -> nil end)
        {part, effect, _tail} = Enum.max_by(rings, &elem(&1, 2))
        {:ok, %{seconds: seconds, part: part, effect: effect}}
    end
  end

  defp longest_ring(error), do: error

  defp cut_short(%{seconds: seconds, part: part, effect: effect}, song) do
    kind = if Enum.any?(song.buses, &(&1.name == part)), do: "bus", else: "part"
    seconds = :erlang.float_to_binary(seconds / 1, decimals: 1)
    part = if part == :song, do: "the song", else: "#{kind} #{part}"

    "the render ends as the last notes fade, cutting short the #{effect} of #{part}, which rings #{seconds} seconds on; --ring-out keeps it"
  end

  # The tempo the music ends at: the song's own, or where the loop that ends last ends.
  defp end_tempo(%Song{tempos: nil} = song, _seconds), do: {:ok, song.tempo}

  defp end_tempo(song, seconds) do
    ending = Enum.filter(song.loops, &(&1.passes != nil))

    with {:ok, ends} <- map_ok(ending, &ends(&1, song)) do
      case {ends, seconds} do
        {[], _seconds} ->
          {:ok, song.tempo}

        {_ends, seconds} when seconds != nil and length(ending) < length(song.loops) ->
          {:ok, song.tempo}

        _ending ->
          {:ok, ends |> Enum.max_by(&elem(&1, 0)) |> elem(1)}
      end
    end
  end

  defp check(%Song{live: [_ | _]}, _seconds) do
    {:error, "a song with live_audio cannot render, as it plays the sound card's input"}
  end

  defp check(%Song{loops: loops}, nil) do
    if Enum.any?(loops, &(&1.on == nil and &1.passes == nil)) do
      {:error,
       "the song's music plays until mx stops it; give --seconds to say how long to render"}
    else
      :ok
    end
  end

  defp check(_song, seconds) when is_number(seconds) and seconds > 0, do: :ok
  defp check(_song, seconds), do: {:error, "--seconds takes a length above 0, not #{seconds}"}

  defp check_ring_out(ring_out) when is_boolean(ring_out) or is_nil(ring_out), do: :ok

  defp check_ring_out(ring_out) do
    ring_out = inspect(ring_out)
    {:error, "--ring-out takes true or false, not #{ring_out}"}
  end

  # The seconds of music the render plays: until its music ends, or for `seconds` when that is
  # sooner or the music does not end.
  defp total(song, seconds, share) do
    ending = Enum.filter(song.loops, &(&1.passes != nil))
    endless? = length(ending) < length(song.loops)

    with {:ok, ends} <- map_ok(ending, &ends(&1, song)) do
      music = ends |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end) |> Kernel./(share)
      {:ok, if(endless?, do: seconds, else: min(music, seconds || music))}
    end
  end

  # The seconds at which a loop's last pass ends, at the song's own tempo, and the tempo then.
  defp ends(loop, song) do
    sections = loop.music.sections
    window = elem(sections, tuple_size(sections) - 1).beats

    played =
      Enum.reduce_while(0..(loop.passes - 1)//1, {:ok, 0}, fn pass, {:ok, start} ->
        case Pass.events(loop, pass) do
          {:ok, %{beats: beats}} -> {:cont, {:ok, start + beats}}
          error -> {:halt, error}
        end
      end)

    with {:ok, beats} <- played do
      {timeline, _start} = Tempo.through(song.tempos, song.tempo, max(loop.passes - 1, 0), window)
      {:ok, {Tempo.time_at(timeline, beats) / 1_000_000, Tempo.tempo_at(timeline, beats)}}
    end
  end

  @doc false
  def map_ok(items, fun) do
    mapped =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, done} ->
        case fun.(item) do
          {:ok, value} -> {:cont, {:ok, [value | done]}}
          error -> {:halt, error}
        end
      end)

    case mapped do
      {:ok, done} -> {:ok, Enum.reverse(done)}
      error -> error
    end
  end

  defp left_out(song) do
    for loop <- song.loops, line = left_out_line(loop), do: line
  end

  defp left_out_line(%{on: on, name: name}) when on != nil do
    "part #{name} waits for MIDI or OSC input, which a render does not have, so it plays nothing"
  end

  defp left_out_line(_loop), do: nil

  # Every render starts at the same time, so each beat's time rounds the same way on every run.
  @start_us 0

  defp check_loudness(nil), do: :ok
  defp check_loudness(target) when is_number(target) and target <= 0, do: :ok

  defp check_loudness(_target) do
    {:error,
     "--loudness takes the loudness to bring the file to in LUFS, a number at or below 0, such as -14"}
  end

  @ceiling -1.0

  # Scales the file towards the loudness asked for, no further than a peak at the ceiling, and
  # returns the loudness it has.
  defp settle(out, target) do
    measured = Loudness.measure(out)

    if measured && target do
      %{peak: peak} = Recording.level(out)
      wanted = target - measured
      gain = if wanted > 0, do: min(wanted, max(@ceiling - peak, 0.0)), else: wanted
      if gain != 0, do: Loudness.scale(out, gain)

      if gain < wanted do
        reached = :erlang.float_to_binary(measured + gain, decimals: 1)
        target = if target == trunc(target), do: trunc(target), else: target

        IO.puts(
          "The loudness reached #{reached} LUFS, not #{target}: more would push the peak past -1 dB. A limiter on the song, fx: [limiter: []], allows more."
        )
      end

      measured + gain
    else
      measured
    end
  end

  defp run(song, out, seconds, follow, share, total, {ring_out, ring}, heard) do
    start_us = @start_us
    Clock.start_render(start_us)
    Process.flag(:trap_exit, true)

    try do
      {:ok, engine} = Mxs.start_link(live: false, record: out, fade_ms: 0)
      {:ok, inputs} = Inputs.start_link(name: nil, midi: false)
      render = self()

      {:ok, band} =
        Band.start_link(
          song: song,
          start_us: start_us,
          ahead_ms: div(@ahead_us, 1000),
          share: share,
          follow: follow,
          play: &Mxs.play/2,
          new_id: &Mxs.new_id/0,
          prepare: &Mxs.prepare/1,
          load_sample: &Mxs.load_sample/2,
          start_fx: &Mxs.start_fx/1,
          stop_fx: &Mxs.stop_fx/2,
          start_part: &Mxs.start_part(&1, &2, beats: true),
          main: &Mxs.set_main/1,
          buses: &Mxs.set_buses/1,
          hand: &Mxs.pass/5,
          cut: &Mxs.cut/2,
          place_beats: &Mxs.place_beats/1,
          set_tempo: &Mxs.set_tempo/2,
          mute: &Mxs.mute/2,
          solo: &Mxs.solo/2,
          out: fn _at_us, message -> send(render, {:sent, self(), elem(message, 0)}) end,
          inputs: &Inputs.snapshot_at(inputs, &1, &2),
          set: &Inputs.put(inputs, &1, &2, &3, &4),
          worked_out: &Inputs.worked_out(inputs, &1, &2),
          on_end: fn -> send(render, :song_ended) end,
          on_fail: fn name, reason -> send(render, {:part_failed, name, reason}) end
        )

      for name <- Keyword.get(heard, :mute, []), do: :ok = Band.mute(band, name)
      :ok = Band.solo(band, Keyword.get(heard, :solo, []))
      stop_us = if seconds, do: start_us + round(seconds * 1_000_000)
      progress = %{start_us: start_us, total: total, printed_ms: now_ms()}

      case play(band, start_us, stop_us, MapSet.new(), progress) do
        {:part_failed, name, reason} ->
          for pid <- [band, inputs, engine], do: GenServer.stop(pid)
          File.rm(out)
          {:error, "part #{name}: " <> failure(reason)}

        last_us ->
          rendered(band, last_us, start_us, total, {ring_out, ring})
          GenServer.stop(inputs)
          GenServer.stop(engine)
      end
    after
      Clock.stop_render()
    end
  end

  defp failure({%{__exception__: true} = error, _stack}), do: Exception.message(error)
  defp failure(reason), do: inspect(reason)

  defp rendered(band, last_us, start_us, total, {ring_out, ring}) do
    print_progress(total, total)
    cut(band, last_us - @step_us + @ahead_us)
    GenServer.stop(band)

    case {ring_out, ring} do
      {false, _ring} ->
        Mxs.render_to(start_us + round(total * 1_000_000))

      {true, %{seconds: seconds}} ->
        faded_us = fade(last_us, last_us + @fade_us)
        Clock.advance(faded_us + round(seconds * 1_000_000))
        Mxs.render_to(faded_us + round(seconds * 1_000_000))

      _as_ever ->
        fade(last_us, last_us + @fade_us)
    end
  end

  # The engine holds each pass whole, so what a loop would not have sent by the last step is
  # dropped.
  defp cut(band, until_us) do
    beat = band |> Band.timeline() |> Band.beat_at(until_us)
    for pid <- Band.loops(band), name = name(pid), do: Mxs.cut(name, beat)
  end

  defp play(band, now_us, stop_us, told, progress) do
    receive do
      :song_ended -> now_us
      {:part_failed, name, reason} -> {:part_failed, name, reason}
    after
      0 ->
        if stop_us != nil and now_us >= stop_us do
          now_us
        else
          wakes = band |> Band.loops() |> Enum.sort_by(&name/1) |> Enum.map(&tick/1)
          told = tell_sent(told)

          next_us =
            case Enum.min([stop_us || :infinity | wakes]) do
              :infinity -> now_us + @step_us
              next_us -> max(next_us, now_us + @step_us)
            end

          Mxs.render_to(next_us - @step_us)
          Clock.advance(next_us)
          play(band, next_us, stop_us, told, progressed(progress, next_us))
        end
    end
  end

  defp progressed(progress, now_us) do
    if now_ms() - progress.printed_ms >= @progress_ms do
      rendered = min((now_us - progress.start_us) / 1_000_000, progress.total)
      print_progress(rendered, progress.total)
      %{progress | printed_ms: now_ms()}
    else
      progress
    end
  end

  defp print_progress(rendered, total) do
    rendered = :erlang.float_to_binary(rendered * 1.0, decimals: 1)
    total = :erlang.float_to_binary(total * 1.0, decimals: 1)
    IO.puts("rendered #{rendered} of #{total} seconds")
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp tell_sent(told) do
    receive do
      {:sent, pid, kind} ->
        part = name(pid)

        if {part, kind} in told do
          tell_sent(told)
        else
          IO.puts(
            "part #{part} sends #{kind |> Atom.to_string() |> String.upcase()}, which a render leaves out"
          )

          tell_sent(MapSet.put(told, {part, kind}))
        end
    after
      0 -> told
    end
  end

  defp name(pid) do
    :sys.get_state(pid).loop.name
  catch
    :exit, _ -> nil
  end

  # Gives the time the loop next needs a tick; a loop that has ended since the band listed it is
  # left alone.
  defp tick(pid) do
    send(pid, :tick)
    :sys.get_state(pid).wake_us || :infinity
  catch
    :exit, _ -> :infinity
  end

  defp fade(now_us, until_us) do
    now_us = now_us + @step_us
    Clock.advance(now_us)

    if Mxs.render_to(now_us) and now_us < until_us, do: fade(now_us, until_us), else: now_us
  end
end
