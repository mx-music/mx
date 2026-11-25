defmodule Mx.Hum.Recorder do
  @moduledoc """
  Records a hum against a click and turns it into a song, for `mix mx.hum --record`.

  The click is mx's closed hi-hat, a tick without a pitch, louder on the first beat of each bar: a bar of 4 beats as a count-in, then every beat until `wait` returns, which is when Enter is pressed.
  The sound card's input is recorded from the first click, apart from the main output, so the click is not in the recording, and a click the microphone picks up from the speakers has no pitch to be a note.
  Beat 0 is the first beat after the count-in, and a note hummed during the count-in is left out.

  Whatever can be refused is refused before the first click: a recording or song that exists without `force:`, a folder that cannot be written, and an input that runs at another sample rate than the output.
  """

  alias Mx.{Audio, Hum, Recording}
  alias Mx.Engine.Mxs

  @count_in 4
  @lead_us 300_000
  @ahead_us 200_000

  @doc """
  Records a hum to a WAV file at `tempo:` and writes its song, printing what it did; returns `:ok` or `{:error, message}`.
  It takes `out:` for the song, `force:`, `input:`, the sound card's input to record (1 unless given), `synth:`, options for the engine, `source:` to play a mono WAV file in place of the input, and `wait:`, a function that returns once recording should stop.
  """
  def record(wav, opts) when is_binary(wav) and is_list(opts) do
    tempo = Keyword.fetch!(opts, :tempo)
    force = Keyword.get(opts, :force, false)
    out = Keyword.get(opts, :out, Path.rootname(wav) <> ".exs")

    source =
      case opts[:source] do
        nil -> {:input, Keyword.get(opts, :input, 1)}
        path -> {:sample, path}
      end

    with :ok <- Recording.check(wav, force),
         :ok <- Hum.check(out, force),
         IO.puts(
           "Recording #{wav} at #{format(tempo)} bpm after a bar of clicks; press Enter to stop."
         ),
         :ok <- play_and_record(wav, tempo, source, opts) do
      seconds = :erlang.float_to_binary(Recording.seconds(wav), decimals: 1)
      IO.puts("Recorded #{wav}: #{seconds} seconds.")
      transcribe(wav, out, tempo)
    end
  end

  defp play_and_record(wav, tempo, source, opts) do
    Process.flag(:trap_exit, true)

    synth_opts =
      [input: match?({:input, _}, source), input_advice: nil] ++ Keyword.get(opts, :synth, [])

    case Mxs.start_link(synth_opts) do
      {:ok, engine} ->
        start_us = System.os_time(:microsecond) + @lead_us
        beat_us = round(60_000_000 / tempo)

        result =
          with :ok <- Mxs.record_input(wav, source, start_us) do
            clicker = spawn_link(fn -> click(start_us, beat_us, 0) end)
            Keyword.get(opts, :wait, fn -> IO.gets("") end).()
            Process.unlink(clicker)
            Process.exit(clicker, :kill)
            Mxs.stop_input()
          end

        GenServer.stop(engine)
        result

      {:error, message} ->
        {:error, message}
    end
  end

  defp click(start_us, beat_us, beat) do
    at_us = start_us + beat * beat_us
    wait_us = at_us - @ahead_us - System.os_time(:microsecond)
    wait_us |> div(1000) |> max(0) |> Process.sleep()
    vel = if rem(beat, 4) == 0, do: 0.4, else: 0.25
    Mxs.play(at_us, [{:note, nil, :closed_hihat, nil, [vel: vel], nil}])
    click(start_us, beat_us, beat + 1)
  end

  defp transcribe(wav, out, tempo) do
    {:ok, %{samples: samples, rate: rate}} = Audio.read(wav)

    case Hum.transcribe(samples, rate, tempo, beat_0: @count_in * 60 / tempo) do
      %{notes: []} ->
        {:error, "found no notes in #{wav}"}

      %{notes: notes, beats: beats, left_out: left_out} ->
        if left_out > 0, do: IO.puts("Left out #{notes(left_out)} hummed during the count-in.")
        out |> Hum.write(notes, beats, tempo) |> IO.puts()
    end
  end

  defp format(tempo) when tempo == trunc(tempo), do: trunc(tempo)
  defp format(tempo), do: tempo

  defp notes(1), do: "1 note"
  defp notes(count), do: "#{count} notes"
end
