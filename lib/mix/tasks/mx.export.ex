defmodule Mix.Tasks.Mx.Export do
  @shortdoc "Writes a song as a MusicXML score, a MIDI file or an ABC tune"

  @moduledoc """
  Writes a song as a MusicXML score, one part of the score for each part of the song that plays notes, through the whole of its music once.

      mx export song.exs
      mx export song.exs --time 12/8 --key bm --out song.mxl

  The score is written beside the song with the extension .musicxml unless `--out` names it, compressed when that ends in .mxl, and `--force` writes over a file that exists.
  `--time` gives the time signature, the song's `meter:` over 4 unless given, so 4/4 for a song that gives no meter, and `--key` the key its notes are spelled in, such as d, bm or fsm, the song's `key:` unless given, or C major when it states none.
  `--pickup` gives the length in beats of a pickup bar, written as bar 0 before the first full bar, such as 0.5 for an eighth note; it must be shorter than a bar.
  `--title` gives the score's title, which is otherwise the song file's name.
  A part that plays no notes with a pitch, such as drums or samples, or that waits for input, is left out, and the task says so.

  When `--out` ends in .mid or .midi it writes a MIDI file instead: one track per part, named after the part, each note at its vel, with the song's tempo and the time signature and key given.
  The tracks name no instrument, since mx's synths have no General MIDI number.

  When `--out` ends in .abc it writes an ABC tune: one voice per part, named after it, with the time signature and key given and the song's tempo.
  ABC has no place for velocity, the pedal, synths or effects, and the task says they are left out.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    strict = [
      out: :string,
      time: :string,
      key: :string,
      pickup: :string,
      title: :string,
      force: :boolean
    ]

    {opts, [path]} = OptionParser.parse!(args, strict: strict)
    out = Keyword.get_lazy(opts, :out, fn -> Path.rootname(path) <> ".musicxml" end)
    Mx.Command.start()

    writer =
      case Path.extname(out) do
        extension when extension in [".mid", ".midi"] -> Mx.MIDI
        ".abc" -> Mx.ABC
        _other -> Mx.MusicXML
      end

    case writer.write(path, out, Keyword.take(opts, [:time, :key, :pickup, :title, :force])) do
      {:ok, report} ->
        Mx.Command.info("Wrote #{out}")

        for %{name: name, notes: notes, low: low, high: high} <- report.parts do
          Mx.Command.info("#{name}: #{notes} notes from #{low} to #{high}")
        end

        for {name, why} <- report.left_out do
          Mx.Command.info("#{name} is left out: #{why}")
        end

        report |> Map.get(:notes, []) |> Enum.each(&Mx.Command.info/1)

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end
end
