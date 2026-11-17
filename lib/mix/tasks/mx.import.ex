defmodule Mix.Tasks.Mx.Import do
  @shortdoc "Writes a MusicXML score as a song"

  @moduledoc """
  Reads a MusicXML score and writes it as a song beside it, one part per part of the score, that plays the whole score once.

      mix mx.import score.mxl --tempo 100 --part "Soprano=oboe" --part "Bass=cello"

  `--part` names the synth a part plays on, and a part without one plays on tri.
  `--tempo` sets the tempo, which otherwise comes from the score's first metronome mark.
  `--out` names another path for the song, and `--force` writes over a song that exists.
  """

  use Mix.Task

  alias Mx.Score

  @impl true
  def run(args) when is_list(args) do
    {opts, [path]} =
      OptionParser.parse!(args,
        strict: [out: :string, part: :keep, tempo: :string, force: :boolean]
      )

    out = Keyword.get(opts, :out, Path.rootname(path) <> ".exs")

    score =
      case Score.read(path) do
        {:ok, score} -> score
        {:error, message} -> Mx.Command.fail(message)
      end

    synths = synths(opts, score, path)
    tempo = tempo(opts[:tempo], score.tempo)

    if File.exists?(out) and not Keyword.get(opts, :force, false) do
      Mx.Command.fail("#{out} already exists; give --force to write over it")
    end

    parts = Enum.map(score.parts, &{&1, Map.get(synths, &1.name, :tri)})
    song = song(score, parts, tempo, Path.basename(path), out)
    File.write!(out, [Code.format_string!(song, locals_without_parens: [part: 2]), "\n"])

    Mx.Command.info("Wrote #{out}")

    for {part, synth} <- parts do
      Mx.Command.info(summary(part, synth))
    end
  end

  defp synths(opts, score, path) do
    names = Enum.map(score.parts, & &1.name)

    for given <- Keyword.get_values(opts, :part), into: %{} do
      {name, synth} =
        case String.split(given, "=", parts: 2) do
          [name, synth] -> {String.trim(name), String.trim(synth)}
          _other -> Mx.Command.fail(~s(give each part with its synth, such as --part "Soprano=oboe"))
        end

      synth = synth(synth)
      part = Enum.find(names, &(String.downcase(&1) == String.downcase(name)))

      if part == nil do
        file = Path.basename(path)
        parts = sentence(names)
        Mx.Command.fail("no part named #{name} in #{file}; its parts are #{parts}")
      end

      {part, synth}
    end
  end

  defp synth(name) do
    case Enum.find(Mx.Synths.synths(), &(&1 == name)) do
      nil -> Mx.Command.fail("unknown synth #{name}")
      synth -> synth
    end
  end

  defp tempo(nil, nil), do: Mx.Command.fail("give the score's tempo with --tempo")
  defp tempo(nil, tempo), do: tempo

  defp tempo(given, _tempo) do
    case Float.parse(given) do
      {tempo, ""} when tempo > 0 -> if tempo == trunc(tempo), do: trunc(tempo), else: tempo
      _other -> Mx.Command.fail("--tempo takes beats per minute, such as --tempo 100")
    end
  end

  defp sentence([one]), do: one
  defp sentence(names), do: Enum.join(Enum.drop(names, -1), ", ") <> " and " <> List.last(names)

  defp summary(part, synth) do
    notes =
      for bar <- part.bars,
          voice <- bar.voices,
          group <- voice,
          note <- group.notes,
          not note.continues,
          do: note

    name = part.name

    case notes do
      [] ->
        "#{name} on #{synth}: no notes"

      notes ->
        count = length(notes)
        low = notes |> Enum.min_by(& &1.midi) |> Map.fetch!(:name)
        high = notes |> Enum.max_by(& &1.midi) |> Map.fetch!(:name)
        "#{name} on #{synth}: #{count} notes from :#{low} to :#{high}"
    end
  end

  defp song(score, parts, tempo, file, out) do
    song_module = song_module(out)
    names = loop_names(Enum.map(parts, fn {part, _synth} -> part.name end))
    rendered = Enum.map(parts, fn {part, synth} -> render(part, synth, score.order) end)

    # A bar plays the same wherever the score plays it, unless a tie into it or out of it differs,
    # and then each time it plays is written apart.
    same? =
      Enum.all?(rendered, fn bars ->
        bars
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 2))
        |> Enum.all?(fn {_number, musics} -> length(Enum.uniq(musics)) == 1 end)
      end)

    bars =
      Enum.map_join(Enum.zip(rendered, names), "\n\n", fn {bars, name} ->
        bars
        |> Enum.uniq_by(&if(same?, do: elem(&1, 0), else: {elem(&1, 0), elem(&1, 1)}))
        |> Enum.sort_by(&{elem(&1, 0), elem(&1, 1)})
        |> Enum.map_join("\n", fn {number, time, music} ->
          key = if same?, do: "#{number}", else: "{#{number}, #{time}}"
          line = "  defp bar(:#{name}, #{key}), do: #{music}"

          if String.length(line) > 98 do
            "  defp bar(:#{name}, #{key}) do\n    #{music}\n  end"
          else
            line
          end
        end)
      end)

    order = if same?, do: order(score.runs), else: inspect(times(score.order), limit: :infinity)

    declarations =
      Enum.map_join(Enum.zip(parts, names), "\n", fn {{_part, synth}, name} ->
        defaults = if Mx.Synths.option?(synth, :vel), do: ", defaults: [vel: 0.6]", else: ""
        "  part :#{name}, synth: :#{synth}#{defaults}"
      end)

    players =
      Enum.map_join(names, ",\n", fn name ->
        "      part(:#{name}, seq(Enum.map(order(), &bar(:#{name}, &1))))"
      end)

    title = title(score.title)
    beats = format_beats(beats(score))

    moduledoc =
      [
        "#{title}, imported from #{file} by mix mx.import.",
        "Each part's bars are written one to a line where they fit, as the bar's number and its music; a bar of several voices plays them together.",
        "A note's length is in beats, a quarter note being a beat; a note tied over a bar line sounds for the whole tie, given as its sustain, and the note it ties into is a rest.",
        "Notes play at vel 0.6, and a dynamic marked in the score gives the notes after it another vel.",
        "The whole score plays once, #{beats} beats."
      ]
      |> Enum.map_join("\n", &doc_line/1)

    """
    defmodule #{song_module} do
      @moduledoc \"""
    #{moduledoc}
      \"""

      use Mx.Song, tempo: #{tempo}

    #{declarations}

      def song do
        together([
    #{players}
        ])
      end

      # The bars in the order the score plays them, its repeats taken.
      defp order, do: #{order}

    #{bars}
    end
    """
  end

  # Each sentence a line of its own in the moduledoc, wrapped at 98 columns.
  defp doc_line(sentence) do
    sentence
    |> String.split(" ")
    |> Enum.reduce([], fn
      word, [line | lines] when byte_size(line) + byte_size(word) < 96 ->
        [line <> " " <> word | lines]

      word, lines ->
        [word | lines]
    end)
    |> Enum.reverse()
    |> Enum.map_join("\n", &("  " <> &1))
  end

  # The module is named after the song, so two songs whose parts share a name can load side by
  # side.
  defp song_module(out) do
    name =
      out
      |> Path.basename()
      |> Path.rootname()
      |> String.replace(~r/[^A-Za-z0-9]+/, "_")
      |> Macro.camelize()

    if name =~ ~r/^[A-Z]/, do: name, else: "Score" <> name
  end

  defp times(order) do
    {keys, _seen} =
      Enum.map_reduce(order, %{}, fn number, seen ->
        time = Map.get(seen, number, 0) + 1
        {{number, time}, Map.put(seen, number, time)}
      end)

    keys
  end

  # Each time a bar plays, as {number, time, music}, with ties resolved in the order the bars
  # play.
  defp render(part, synth, order) do
    bars = Map.new(part.bars, &{&1.number, &1})
    keys = times(order)
    {sustains, continued} = ties(bars, keys)
    sustain? = Mx.Synths.option?(synth, :sustain)
    vel? = Mx.Synths.option?(synth, :vel)

    for {number, time} = key <- keys do
      voices =
        bars
        |> Map.fetch!(number)
        |> Map.fetch!(:voices)
        |> Enum.with_index(fn groups, voice ->
          groups
          |> Enum.with_index(fn group, index ->
            heads =
              for {head, head_index} <- Enum.with_index(group.notes),
                  {key, voice, index, head_index} not in continued,
                  do: {head.name, Map.fetch!(sustains, {key, voice, index, head_index})}

            {heads, group.length, if(vel?, do: vel(group.mark), else: 0.6), sustain?}
          end)
          |> voice_music()
        end)

      music =
        case voices do
          [one] -> one
          many -> "together([" <> Enum.join(many, ", ") <> "])"
        end

      {number, time, music}
    end
  end

  # Follows each tie into the note of its name, marked as tied into, that starts where the tie
  # ends, in its own voice if one does and in another otherwise, and gives the note that starts it
  # the length of the whole tie. A bar's notes are taken in the order they start, across voices,
  # so a tie into a voice written before its own is found.
  defp ties(bars, keys) do
    {_start, _open, sustains, continued} =
      Enum.reduce(keys, {0, [], %{}, MapSet.new()}, fn {number, _time} = key,
                                                       {start, open, sustains, continued} ->
        voices = bars |> Map.fetch!(number) |> Map.fetch!(:voices)

        heads =
          for {groups, voice} <- Enum.with_index(voices),
              {group, index, beat} <- onsets(groups, start),
              {head, head_index} <- Enum.with_index(group.notes),
              do: {beat, voice, {key, voice, index, head_index}, group.length, head}

        {open, sustains, continued} =
          heads
          |> Enum.sort_by(fn {beat, voice, _, _, _} -> {beat, voice} end)
          |> Enum.reduce({open, sustains, continued}, &tie/2)

        ends = for groups <- voices, do: start + (groups |> Enum.map(& &1.length) |> Enum.sum())
        {Enum.max([start | ends]), open, sustains, continued}
      end)

    {sustains, continued}
  end

  defp onsets(groups, start) do
    {onsets, _end} =
      groups
      |> Enum.with_index()
      |> Enum.map_reduce(start, fn {group, index}, beat ->
        {{group, index, beat}, beat + group.length}
      end)

    onsets
  end

  # An open tie is {owner, owner_start, end, voice, name}, owner being the note that sounds for
  # it.
  defp tie({beat, voice, id, length, head}, {open, sustains, continued}) do
    case head.continues && joined(open, head.name, voice, beat) do
      {owner, owner_start, _end, _voice, name} = tie ->
        open = List.delete(open, tie)

        open =
          if head.tie, do: [{owner, owner_start, beat + length, voice, name} | open], else: open

        sustains = Map.put(sustains, owner, beat + length - owner_start)
        {open, sustains, MapSet.put(continued, id)}

      _none ->
        open = if head.tie, do: [{id, beat, beat + length, voice, head.name} | open], else: open
        {open, Map.put(sustains, id, length), continued}
    end
  end

  # The open tie of this name that ends at `beat`, its own voice's first.
  defp joined(open, name, voice, beat) do
    ending =
      Enum.filter(open, fn {_, _, at, _, held} -> held == name and abs(at - beat) < 1.0e-6 end)

    Enum.find(ending, &(elem(&1, 3) == voice)) || List.first(ending)
  end

  defp vel(mark) when mark in ["pppp", "ppp", "pp"], do: 0.3
  defp vel("p"), do: 0.45
  defp vel("mp"), do: 0.5
  defp vel(mark) when mark in ["mf", nil], do: 0.6
  defp vel("f"), do: 0.8
  defp vel(mark) when mark in ["ff", "fff", "ffff"], do: 1

  # A voice of plain notes and rests is a keyword seq; one with chords, dynamics or ties writes
  # each note.
  defp voice_music(items) do
    plain? =
      Enum.all?(items, fn {heads, beats, vel, _sustain?} ->
        vel == 0.6 and length(heads) <= 1 and
          Enum.all?(heads, fn {_name, sustain} -> sustain == beats end)
      end)

    if plain? do
      pairs =
        Enum.map_join(items, ", ", fn
          {[], beats, _vel, _sustain?} -> "r: #{format_length(beats)}"
          {[{name, _}], beats, _vel, _sustain?} -> "#{name}: #{format_length(beats)}"
        end)

      "seq(#{pairs})"
    else
      "seq([" <> Enum.map_join(items, ", ", &item_music/1) <> "])"
    end
  end

  defp item_music({[], beats, _vel, _sustain?}), do: "rest(#{format_length(beats)})"

  defp item_music({heads, beats, vel, sustain?}) do
    pitch =
      case heads do
        [{name, _}] -> ":#{name}"
        heads -> "[" <> Enum.map_join(heads, ", ", fn {name, _} -> ":#{name}" end) <> "]"
      end

    sustains = Enum.map(heads, &elem(&1, 1))

    sustain =
      cond do
        not sustain? or Enum.all?(sustains, &(&1 == beats)) -> []
        length(sustains) == 1 -> ["sustain: #{format_length(hd(sustains))}"]
        true -> ["sustain: [" <> Enum.map_join(sustains, ", ", &format_length/1) <> "]"]
      end

    vel = if vel == 0.6, do: [], else: ["vel: #{vel}"]
    opts = Enum.map_join(vel ++ sustain, &(", " <> &1))
    "note(#{pitch}, #{format_length(beats)}#{opts})"
  end

  # Audiveris and music21 name a score after its file, which says nothing the moduledoc does not.
  defp title(title) when title in [nil, ""], do: "A score"

  defp title(title) do
    if title =~ ~r/\.(mxl|musicxml|xml)$/, do: "A score", else: title
  end

  defp loop_names(names) do
    {loops, _seen} =
      Enum.map_reduce(names, %{}, fn name, seen ->
        base =
          name
          |> String.normalize(:nfd)
          |> String.replace(~r/[^A-Za-z0-9]+/, "_")
          |> String.trim("_")
          |> String.downcase()

        base = if base == "" or base =~ ~r/^\d/, do: "part_" <> base, else: base
        count = Map.get(seen, base, 0) + 1
        loop = if count == 1, do: base, else: "#{base}_#{count}"
        {loop, Map.put(seen, base, count)}
      end)

    loops
  end

  defp beats(score) do
    part = hd(score.parts)
    lengths = Map.new(part.bars, &{&1.number, bar_length(&1)})
    score.order |> Enum.map(&Map.fetch!(lengths, &1)) |> Enum.sum()
  end

  defp bar_length(bar) do
    bar.voices
    |> Enum.map(fn voice -> voice |> Enum.map(& &1.length) |> Enum.sum() end)
    |> Enum.max(fn -> 0 end)
  end

  # Each run of bars is written as a range, or as a list when its numbers skip.
  defp order(runs) do
    runs =
      Enum.map_join(runs, ", ", fn run ->
        first = hd(run)
        last = List.last(run)

        if run == Enum.to_list(first..last//1) do
          "#{first}..#{last}"
        else
          inspect(run, limit: :infinity)
        end
      end)

    "Enum.concat([#{runs}])"
  end

  defp format_length(length) do
    case Enum.find(
           [1, 2, 4, 8, 16, 32, 64, 3, 6, 12, 24, 48, 5, 10, 20, 7, 14, 28],
           &whole?(length * &1)
         ) do
      nil -> format_beats(Float.round(length * 1.0, 4))
      under when under in [1, 2, 4, 8, 16, 32, 64] -> format_beats(length)
      under -> "#{round(length * under)}/#{under}"
    end
  end

  defp whole?(value), do: abs(value - round(value)) < 1.0e-6

  defp format_beats(beats) do
    rounded = Float.round(beats * 1.0, 6)

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      Float.to_string(rounded)
    end
  end
end
