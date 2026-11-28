defmodule Mix.Tasks.Mx.Hum do
  @shortdoc "Turns a hummed melody into a song, from a recording or recorded against a click"

  @moduledoc """
  Reads a recording of one voice humming, singing or whistling a melody, and writes it as a song
  beside the recording.

      mx hum hum.wav --tempo 90
      mx hum hum.wav --tempo 90 --out tune.exs --force

  The recording is WAV or AIFF, mono or stereo, at any sample rate, and `--tempo` is the tempo it
  was hummed at.
  The song is named after the recording with `.exs`, or `--out` names it, and a song that exists
  is written over only with `--force`.
  It has one part, hum, on mx's default synth, that plays the melody again and again as a seq of
  note names and rests, as `Mx.Hum` describes.

      mx hum --record hum.wav --tempo 90

  `--record` plays a click at the tempo, a bar of 4 beats as a count-in and then every beat,
  records the sound card's first input to the file until Enter is pressed, and turns it into a
  song as above, with beat 0 on the first beat after the count-in, as `Mx.Hum.Recorder` describes.
  `--input 2` records another input, and `--force` records over a recording that exists and writes
  over its song.
  """

  use Mix.Task

  alias Mx.{Audio, Hum}

  @switches [
    tempo: :float,
    out: :string,
    force: :boolean,
    record: :string,
    input: :integer
  ]

  @impl true
  def run(args) when is_list(args) do
    {opts, files} = OptionParser.parse!(args, strict: @switches)
    tempo = opts[:tempo] || Mx.Command.fail("give the hum's tempo with --tempo")

    case {opts[:record], files} do
      {nil, [path]} -> transcribe(path, tempo, opts)
      {wav, []} when wav != nil -> record(wav, tempo, opts)
      _ -> Mx.Command.fail("give one recording, such as mix mx.hum hum.wav --tempo 90")
    end
  end

  defp record(wav, tempo, opts) do
    Mx.Command.start()
    recorder_opts = [tempo: tempo] ++ Keyword.take(opts, [:out, :force, :input])

    case Hum.Recorder.record(wav, recorder_opts) do
      :ok -> :ok
      {:error, message} -> Mx.Command.fail(message)
    end
  end

  defp transcribe(path, tempo, opts) do
    out = opts[:out] || Path.rootname(path) <> ".exs"

    with :ok <- Hum.check(out, opts[:force] || false),
         {:ok, %{samples: samples, rate: rate}} <- Audio.read(path) do
      case Hum.transcribe(samples, rate, tempo) do
        %{notes: []} ->
          Mx.Command.fail("found no notes in #{path}")

        %{notes: notes, beats: beats} ->
          out |> Hum.write(notes, beats, tempo) |> Mx.Command.info()
      end
    else
      {:error, message} -> Mx.Command.fail(message)
    end
  end
end
