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
  `--render` writes the song to a stereo WAV file offline instead of playing it, for `--seconds` when its music does not end, printing its progress as it goes, such as `rendered 37.5 of 148.0 seconds`, and then the same report.
  `--no-ring-out` with `--render` leaves out the notes still sounding when the music ends, which a render otherwise lets fade for up to four seconds, so the file ends where the music ends.
  A MusicXML score, a MIDI file or an ABC tune plays as the song `mx import` would write from it, without writing it, taking `--part`, `--tempo`, `--grid` and `--tune` as `mx import` does.
  `--share` plays or renders the song at that share of its tempo, from 0.25 to 4, so `--share 0.5` plays it at half speed.

  `--output` and `--input` name the devices to play through and to read live audio from, `--rate` the sample rate in Hz, and `--buffer` the frames the device asks for at a time; each is the device's default when not given, and `mix mx.devices` lists what each device takes.
  `config :mx, output: "Scarlett 2i2"` sets any of the four for the project, and an option given here overrides it.
  A render runs at 48000 Hz, so `--rate` and `--buffer` do not apply to it.
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
