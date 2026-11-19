defmodule Mix.Tasks.Mx.Import do
  @shortdoc "Writes a MusicXML score, a MIDI file or an ABC tune as a song"

  @moduledoc """
  Reads a MusicXML score and writes it as a song beside it, one part per part of the score, that plays the whole score once.

      mx import score.mxl --tempo 100 --part "Soprano=oboe" --part "Bass=cello"
      mx import piece.mid --grid 1/12 --part "Right=piano"

  `--part` names the synth a part plays on, and a part without one plays on tri.
  `--tempo` sets the tempo, which otherwise comes from the score's first metronome mark.
  `--out` names another path for the song, and `--force` writes over a song that exists.
  The syllables of text, slurs, trills and other ornaments, fermatas, grace notes and articulations of a score are left out, and the task counts each kind after the parts.

  A file ending in .mid or .midi is read as a MIDI file, one part per track that plays notes, or per channel when a single track holds them all, each note at the vel it was struck with.
  Its notes move to the nearest sixteenth note, and `--grid` names another division of a whole note, such as 1/32, or 1/12 for eighth-note triplets.
  The song plays each tempo change of the file at its beat, moved to the nearest step of the grid as a note is, unless `--tempo` is given, when the task names each change as left out.
  Notes on channel 10, which General MIDI keeps for drums, the presses of the sustain pedal and other controller messages are left out, and the task counts them part by part.

  A file ending in .abc is read as ABC notation, and `--tune` picks a tune by its X: number from a file of several, the first unless given; the task then lists the file's tunes.
  Each voice is a part, or the tune is one part named after its title, and chord symbols, decorations, lyrics and other text are left out, the task saying how many of each.
  """

  use Mix.Task

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} =
      OptionParser.parse!(args,
        strict: [
          out: :string,
          part: :keep,
          tempo: :string,
          force: :boolean,
          grid: :string,
          tune: :integer
        ]
      )

    imported =
      case Mx.Import.song(path, opts) do
        {:ok, imported} -> imported
        {:error, message} -> Mx.Command.fail(message)
      end

    out = imported.out

    if File.exists?(out) and not Keyword.get(opts, :force, false) do
      Mx.Command.fail("#{out} already exists; give --force to write over it")
    end

    File.write!(out, imported.source)
    Mx.Command.info("Wrote #{out}")
    Enum.each(imported.parts ++ imported.left_out ++ imported.tunes, &Mx.Command.info/1)
  end
end
