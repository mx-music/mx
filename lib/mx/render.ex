defmodule Mx.Render do
  @moduledoc """
  Renders a song file offline to a stereo WAV file, as fast as the machine renders it and with no sound card, for `--render`.

  The band, its loops and an offline engine work out the song as they do when it plays, against `Mx.Clock`'s time, which the render moves on to the next time a loop needs to work something out, 10 ms at least.
  At each step every loop is ticked in turn by name and waited for, so its passes reach the engine in the same order on every run, and the engine renders up to that time.
  The render starts at the song's first beat, and ends once its music has ended or `seconds:` have passed, and the notes still sounding have faded, for four seconds at most.
  With `ring_out: false` it leaves that ring out, so the file ends where the music ends.
  MIDI and OSC are not sent, and a loop that waits for input plays nothing; each part left out is named once, a part that sends MIDI or OSC the first time it does.

  While it renders it prints a line such as `rendered 37.5 of 148.2 seconds` about four times a second, and once more when the music has rendered, giving the seconds of music rendered and the seconds it renders in all, until the music ends or for `seconds:`, the fade after it left out.
  """

  alias Mx.{Band, Clock, Inputs, Pass, Recording, Song, Tempo}
  alias Mx.Engine.Mxs

  @ahead_us 500_000
  @step_us 10_000
  @fade_us 4_000_000
  @progress_ms 250

  @doc "Renders the song at `path` to the WAV file `out`, with `seconds:`, `force:`, `ring_out:` and `share:`, the share of its tempo to play it at, 1 unless given, and returns `:ok` once written, or `{:error, message}`; the process given as `follow:` is sent where the beat is, as `Mx.Beat` describes, in the render's own time."
  def render(path, out, opts) when is_binary(path) and is_binary(out) and is_list(opts) do
    seconds = opts[:seconds]
    share = Keyword.get(opts, :share, 1)
    ring_out = Keyword.get(opts, :ring_out, true)

    with :ok <- Band.check_share(share),
         :ok <- check_ring_out(ring_out),
         :ok <- Recording.check(out, Keyword.get(opts, :force, false)),
         {:ok, _apps} <- Application.ensure_all_started(:mx),
         {:ok, song} <- Song.load(path),
         :ok <- check(song, seconds),
         playing = %{song | loops: Enum.filter(song.loops, &(&1.on == nil))},
         {:ok, total} <- total(playing, seconds, share) do
      Enum.each(left_out(song), &IO.puts/1)
      follow = List.wrap(opts[:follow])
      run(playing, out, seconds, follow, share, total, ring_out)
      Enum.each(Recording.report(out), &IO.puts/1)
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

  defp check_ring_out(ring_out) when is_boolean(ring_out), do: :ok

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
      music = Enum.max(ends, fn -> 0 end) / share
      {:ok, if(endless?, do: seconds, else: min(music, seconds || music))}
    end
  end

  # The seconds at which a loop's last pass ends, at the song's own tempo.
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
      {:ok, Tempo.time_at(timeline, beats) / 1_000_000}
    end
  end

  defp map_ok(items, fun) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, done} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, done ++ [value]}}
        error -> {:halt, error}
      end
    end)
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

  defp run(song, out, seconds, follow, share, total, ring_out) do
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
          hand: &Mxs.pass/5,
          cut: &Mxs.cut/2,
          place_beats: &Mxs.place_beats/1,
          set_tempo: &Mxs.set_tempo/2,
          out: fn _at_us, message -> send(render, {:sent, self(), elem(message, 0)}) end,
          inputs: &Inputs.snapshot_at(inputs, &1, &2),
          set: &Inputs.put(inputs, &1, &2, &3, &4),
          worked_out: &Inputs.worked_out(inputs, &1, &2),
          on_end: fn -> send(render, :song_ended) end
        )

      stop_us = if seconds, do: start_us + round(seconds * 1_000_000)
      progress = %{start_us: start_us, total: total, printed_ms: now_ms()}
      last_us = play(band, start_us, stop_us, MapSet.new(), progress)
      print_progress(total, total)
      cut(band, last_us - @step_us + @ahead_us)
      GenServer.stop(band)

      if ring_out,
        do: fade(last_us, last_us + @fade_us),
        else: Mxs.render_to(start_us + round(total * 1_000_000))

      GenServer.stop(inputs)
      GenServer.stop(engine)
    after
      Clock.stop_render()
    end
  end

  # The engine holds each pass whole, so what a loop would not have sent by the last step is
  # dropped.
  defp cut(band, until_us) do
    beat = Band.beat_at(Band.timeline(band), until_us)
    for pid <- Band.loops(band), name = name(pid), do: Mxs.cut(name, beat)
  end

  defp play(band, now_us, stop_us, told, progress) do
    receive do
      :song_ended -> now_us
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

    if Mxs.render_to(now_us) and now_us < until_us, do: fade(now_us, until_us), else: :ok
  end
end
