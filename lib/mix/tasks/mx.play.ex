defmodule Mix.Tasks.Mx.Play do
  @shortdoc "Plays a song file, and plays each saved version of it"

  @moduledoc """
  Plays the loops a song file describes until Enter is pressed, or until the song's music ends.

      mix mx.play song.exs
      mix mx.play song.exs --record session.wav

  Saving the file makes each changed loop take over at the end of its current
  pass. A version that does not load prints its error, and the previous
  version keeps playing.

  `--record` writes everything mx plays to a stereo WAV file, and `--force` records over a file that exists.
  After recording it prints the recording's length and peak, and warns when the recording clipped.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} = Mx.Player.parse(args)
    Mix.Task.run("app.start")

    case Mx.Player.play(path, opts) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
