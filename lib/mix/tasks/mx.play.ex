defmodule Mix.Tasks.Mx.Play do
  @shortdoc "Plays a song file, and plays each saved version of it"

  @moduledoc """
  Plays the loops a song file describes until Enter is pressed, or until the song's music ends.

      mx play song.exs
      mx play song.exs --record session.wav
      mx play song.exs --render song.wav --seconds 60

  Saving the file makes each changed loop take over at the end of its current
  pass. A version that does not load prints its error, and the previous
  version keeps playing.

  `--record` writes everything mx plays to a stereo WAV file, and `--force` records over a file that exists.
  After recording it prints the recording's length and peak, and warns when the recording clipped.
  `--render` writes the song to a stereo WAV file offline instead of playing it, for `--seconds` when its music does not end, and prints the same report.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} = Mx.Player.parse(args)
    Mx.Command.start()

    case Mx.Player.play(path, opts) do
      :ok -> :ok
      {:error, message} -> Mx.Command.fail(message)
    end
  end
end
