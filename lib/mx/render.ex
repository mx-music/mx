defmodule Mx.Render do
  @moduledoc """
  Renders a song file offline to a stereo WAV file, as fast as the machine renders it and with no sound card, for `--render`.

  The band, its loops and an offline engine work out the song as they do when it plays, against `Mx.Clock`'s time, which the render moves on 10 ms at a time.
  At each step every loop is ticked in turn by name and waited for, so its notes reach the engine in the same order on every run, and the engine renders up to that time.
  The render starts at the song's first beat, and ends once its music has ended or `seconds:` have passed, and the notes still sounding have faded, for four seconds at most.
  MIDI and OSC are not sent, and a loop that waits for input plays nothing; each part left out is named once, a part that sends MIDI or OSC the first time it does.
  """

  alias Mx.{Band, Clock, Inputs, Recording, Song}
  alias Mx.Engine.Mxs

  @step_us 10_000
  @fade_us 4_000_000

  @doc "Renders the song at `path` to the WAV file `out`, with `seconds:` and `force:`, and returns `:ok` once written, or `{:error, message}`."
  def render(path, out, opts) when is_binary(path) and is_binary(out) and is_list(opts) do
    seconds = opts[:seconds]

    with :ok <- Recording.check(out, Keyword.get(opts, :force, false)),
         {:ok, _apps} <- Application.ensure_all_started(:mx),
         {:ok, song} <- Song.load(path),
         :ok <- check(song, seconds) do
      Enum.each(left_out(song), &IO.puts/1)
      run(%{song | loops: Enum.filter(song.loops, &(&1.on == nil))}, out, seconds)
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

  defp left_out(song) do
    for loop <- song.loops, line = left_out_line(loop), do: line
  end

  defp left_out_line(%{on: on, name: name}) when on != nil do
    "part #{name} waits for MIDI or OSC input, which a render does not have, so it plays nothing"
  end

  defp left_out_line(_loop), do: nil

  # Every render starts at the same time, so each beat's time rounds the same way on every run.
  @start_us 0

  defp run(song, out, seconds) do
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
          play: &Mxs.play/2,
          new_id: &Mxs.new_id/0,
          prepare: &Mxs.prepare/1,
          load_sample: &Mxs.load_sample/2,
          start_fx: &Mxs.start_fx/1,
          stop_fx: &Mxs.stop_fx/2,
          out: fn _at_us, message -> send(render, {:sent, self(), elem(message, 0)}) end,
          inputs: &Inputs.snapshot_at(inputs, &1, &2),
          set: &Inputs.put(inputs, &1, &2, &3, &4),
          worked_out: &Inputs.worked_out(inputs, &1, &2),
          on_end: fn -> send(render, :song_ended) end
        )

      stop_us = if seconds, do: start_us + round(seconds * 1_000_000)
      last_us = play(band, start_us, stop_us, MapSet.new())
      GenServer.stop(band)
      fade(last_us, last_us + @fade_us)
      GenServer.stop(inputs)
      GenServer.stop(engine)
    after
      Clock.stop_render()
    end
  end

  defp play(band, now_us, stop_us, told) do
    receive do
      :song_ended -> now_us
    after
      0 ->
        if stop_us != nil and now_us >= stop_us do
          now_us
        else
          band |> Band.loops() |> Enum.sort_by(&name/1) |> Enum.each(&tick/1)
          told = tell_sent(told)
          Mxs.render_to(now_us)
          now_us = now_us + @step_us
          Clock.advance(now_us)
          play(band, now_us, stop_us, told)
        end
    end
  end

  defp tell_sent(told) do
    receive do
      {:sent, pid, kind} ->
        part = name(pid)

        if MapSet.member?(told, {part, kind}) do
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

  # A loop that has ended since the band listed it is left alone.
  defp tick(pid) do
    send(pid, :tick)
    :sys.get_state(pid)
  catch
    :exit, _ -> :ok
  end

  defp fade(now_us, until_us) do
    now_us = now_us + @step_us
    Clock.advance(now_us)

    if Mxs.render_to(now_us) and now_us < until_us, do: fade(now_us, until_us), else: :ok
  end
end
