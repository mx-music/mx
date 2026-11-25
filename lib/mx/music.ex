defmodule Mx.Music do
  @moduledoc """
  Music as values: notes and rests joined one after another or at once, repeated, moved and placed, and played by parts.

  Every function returns a value and records nothing on the side, and raises `ArgumentError` as soon as what it is given cannot play: `note` refuses an unknown name, `part` a note its synth cannot play, `together` two parts of one name, and `song` a note outside any part.
  The song file's loader finds the line in the stacktrace of that error.

  A song's music is split into sections, the items of its outermost seq, looking through repeat.
  Each part becomes a loop whose pass `n` plays that part's notes in section `n`, so every part's pass ends where a section ends, and a saved version takes over there.
  """

  alias Mx.{Notes, Pass, Synths}

  defmodule Note do
    @moduledoc "A note: its pitch, a number, a list of numbers or `:own_note` for a drum, its length in beats and its options."
    defstruct [:pitch, :beats, opts: []]
  end

  defmodule Rest do
    @moduledoc "Silence lasting some beats."
    defstruct [:beats]
  end

  defmodule Seq do
    @moduledoc "Music played one item after another."
    defstruct items: []
  end

  defmodule Together do
    @moduledoc "Music whose items all start at once."
    defstruct items: []
  end

  defmodule Repeat do
    @moduledoc "Music played a number of times in a row, or until mx stops with `times: :forever`."
    defstruct [:music, :times]
  end

  defmodule At do
    @moduledoc "Music of a length whose items start at their beats from its start."
    defstruct [:beats, entries: []]
  end

  defmodule Swing do
    @moduledoc "Music whose notes start at the beat a function returns for the beat they were written on."
    defstruct [:music, :fun]
  end

  defmodule Feel do
    @moduledoc "Music whose notes on each step come early or late and louder or softer by tables, and a little at random."
    defstruct [:music, :step, push: nil, lean: nil, loose: nil, touch: nil]
  end

  defmodule Each do
    @moduledoc "Music whose notes take the options given, or those a function of their beat returns, where they give none of their own."
    defstruct [:music, :opts]
  end

  defmodule Sample do
    @moduledoc "A sample by name or path, lasting some beats, with the options samples take."
    defstruct [:ref, :beats, opts: []]
  end

  defmodule MIDI do
    @moduledoc "A MIDI note sent for some beats, with its velocity and channel."
    defstruct [:note, :beats, opts: []]
  end

  defmodule Message do
    @moduledoc "A step that takes no time: a MIDI controller change, an OSC message, or a value shared with the other loops."
    defstruct [:kind, :args]
  end

  defmodule Change do
    @moduledoc "A change to every sound of a part still playing, or to one of its effects, with `target` being the part's name or `{name, effect}`."
    defstruct [:target, :opts]
  end

  defmodule TempoChange do
    @moduledoc "A change of the whole song's tempo to `bpm`, at once or evenly over `over` beats."
    defstruct [:bpm, over: 0]
  end

  defmodule Part do
    @moduledoc "Music played by one player, with its synth and the loop options it takes."
    defstruct [:name, :music, synth: :tri, fx: [], send: [], defaults: [], midi: nil]
  end

  defmodule Loop do
    @moduledoc "Music that runs a function for each pass of some beats and plays the music it returns, a number of times or as long as the music beside it; or, with `on:`, a pass for each input it waits for."
    defstruct [:beats, :fun, :times, :on, :grid, :line]
  end

  defmodule LoopError do
    @moduledoc "A pass of a loop refused after its function returned, with the line of the song that wrote the loop."
    defexception [:message, :line]
  end

  defmodule Song do
    @moduledoc "The value a song file ends with: its settings, and its music split into sections, each part's notes in each."
    defstruct [
      :music,
      :sections,
      :parts,
      :forever,
      :tempos,
      tempo: 60,
      meter: 4,
      key: nil,
      live_audio: [],
      fx: [],
      buses: [],
      osc_to: nil,
      osc_from: nil
    ]
  end

  @part_options [:synth, :fx, :send, :defaults, :midi]
  @song_options [:tempo, :meter, :key, :music, :live_audio, :fx, :buses, :osc_to, :osc_from]
  @forever "repeat without a count plays until mx stops, so it can only hold the whole of a song's music"

  @doc "A note of a pitch, given as a name, a number or a list of them, lasting some beats, with options for the part's synth."
  def note(pitch, beats, opts \\ []) do
    check_beats("note", beats)

    if not Keyword.keyword?(opts) do
      opts = inspect(opts)
      raise ArgumentError, "note takes options as a keyword list, not #{opts}"
    end

    for change <- Keyword.get(opts, :changes, []) do
      case change do
        {beat, change_opts} when is_number(beat) and beat >= 0 ->
          check_keyword("a note's change", change_opts)

        other ->
          other = inspect(other)
          raise ArgumentError, "changes: takes {beat, options} from beat 0 up, not #{other}"
      end
    end

    check_held(opts)
    %Note{pitch: pitch(pitch), beats: beats, opts: opts}
  end

  defp check_held(opts) do
    if Keyword.has_key?(opts, :held) do
      if Keyword.has_key?(opts, :sustain) do
        raise ArgumentError,
              "a note takes held: or sustain:, not both, as held: is the share of its length its sustain is"
      end

      with {:error, message} <- Synths.check_value(nil, :held, opts[:held]) do
        raise ArgumentError, message
      end
    end
  end

  @doc "A WAV, AIFF or FLAC file by path, a file of a collection as `{collection, name}`, or a file of a GitHub repository as `{:github, repo, ref, path}`, lasting some beats, refusing a sample mx cannot find and an option samples do not take."
  def sample(ref, beats, opts \\ []) when is_atom(ref) or is_binary(ref) or is_tuple(ref) do
    check_beats("sample", beats)
    check_keyword("sample", opts)

    case Enum.find(Keyword.keys(opts), &(not sample_option?(&1))) do
      nil -> :ok
      option -> raise ArgumentError, "samples have no option #{option}"
    end

    case check_ref(ref, opts) do
      :ok -> %Sample{ref: ref, beats: beats, opts: opts}
      {:error, message} -> raise ArgumentError, message
    end
  end

  # A sample on GitHub is downloaded once the song has loaded, where the loop playing it can be
  # named, and its cut checked as it plays.
  defp check_ref(ref, opts) do
    with :ok <- Mx.Samples.check_ref(ref) do
      if is_binary(ref) or match?({:sonic_pi, _}, ref), do: check_file(ref, opts), else: :ok
    end
  end

  defp check_file(ref, opts) do
    with {:ok, path} <- Mx.Samples.path(ref),
         :ok <- Mx.Samples.check_cut(ref, path, opts) do
      Mx.Song.put_played(ref, path, Keyword.get(opts, :normalize, false) == true)
    end
  end

  defp sample_option?(option) do
    Synths.option?(:stereo_player, option) or Mx.Samples.cut_option?(option)
  end

  @doc "A MIDI note on, and its note off after some beats, taking `velocity:` and `channel:`."
  def midi(note, beats, opts \\ []) do
    check_beats("midi", beats)
    if beats == 0, do: raise(ArgumentError, "midi lasts more than 0 beats")
    check_keyword("midi", opts)

    case Enum.find(Keyword.keys(opts), &(&1 not in [:velocity, :channel])) do
      nil -> :ok
      option -> raise ArgumentError, "midi has no option #{option}"
    end

    check_range("midi velocity", Keyword.get(opts, :velocity, 100), 0, 127)
    check_range("midi channel", Keyword.get(opts, :channel, 1), 1, 16)
    %MIDI{note: pitch(note), beats: beats, opts: opts}
  end

  @doc "A MIDI controller change, taking `channel:` and no time."
  def midi_cc(number, value, opts \\ []) do
    check_keyword("midi_cc", opts)

    case Enum.find(Keyword.keys(opts), &(&1 != :channel)) do
      nil -> :ok
      option -> raise ArgumentError, "midi_cc has no option #{option}"
    end

    check_range("midi_cc number", number, 0, 127)
    check_range("midi_cc value", value, 0, 127)
    check_range("midi channel", Keyword.get(opts, :channel, 1), 1, 16)
    %Message{kind: :midi_cc, args: [number, value, opts]}
  end

  @doc "An OSC message to the song's `osc_to`, taking no time."
  def osc(address, args \\ []) do
    if not (is_binary(address) and String.starts_with?(address, "/")) do
      address = inspect(address)
      raise ArgumentError, "osc address must be a string starting with /, not #{address}"
    end

    args = List.wrap(args)

    case Enum.find(args, &(not (is_number(&1) or is_binary(&1)))) do
      nil ->
        %Message{kind: :osc, args: [address, args]}

      arg ->
        arg = inspect(arg)
        raise ArgumentError, "osc arguments must be numbers or strings, not #{arg}"
    end
  end

  @doc "A value shared with every loop from its next pass, taking no time."
  def set(name, value) when is_atom(name), do: %Message{kind: :set, args: [name, value]}

  @doc "A change to every sound of a part still playing, or with `{part, effect}` to one of its effects, taking no time."
  def change(target, opts) do
    check_keyword("change", opts)

    case target do
      name when is_atom(name) ->
        :ok

      {name, effect} when is_atom(name) and is_atom(effect) ->
        :ok

      other ->
        other = inspect(other)
        raise ArgumentError, "change takes a part's name or {part, effect}, not #{other}"
    end

    %Change{target: target, opts: opts}
  end

  defp check_keyword(word, opts) do
    if not Keyword.keyword?(opts) do
      opts = inspect(opts)
      raise ArgumentError, "#{word} takes options as a keyword list, not #{opts}"
    end
  end

  @doc "Raises `ArgumentError` naming the value unless it is an integer from `low` to `high`."
  def check_range(name, value, low, high) do
    if not (is_integer(value) and value in low..high) do
      value = inspect(value)
      raise ArgumentError, "#{name} must be from #{low} to #{high}, not #{value}"
    end
  end

  @doc "A change of every part's tempo to some beats per minute, at once, or with `over:` evenly over that many beats, taking no time."
  def tempo(bpm, opts \\ []) do
    if not (is_number(bpm) and bpm > 0) do
      bpm = inspect(bpm)
      raise ArgumentError, "tempo takes beats per minute above 0, not #{bpm}"
    end

    check_keyword("tempo", opts)

    case Keyword.keys(opts) -- [:over] do
      [] -> :ok
      [option | _] -> raise ArgumentError, "tempo has no option #{option}; it takes over:"
    end

    over = Keyword.get(opts, :over, 0)
    check_beats("tempo's over:", over)
    %TempoChange{bpm: bpm, over: over}
  end

  @doc "A hit of a drum at its own pitch, taking no time, with options for the part's synth."
  def hit(opts \\ []) do
    check_keyword("hit", opts)

    if Keyword.has_key?(opts, :held) do
      raise ArgumentError, "a hit takes no held:, as it has no length to take a share of"
    end

    %Note{pitch: :own_note, beats: 0, opts: opts}
  end

  @doc "Silence lasting some beats."
  def rest(beats) do
    check_beats("rest", beats)
    %Rest{beats: beats}
  end

  @doc "Music played one item after another; an item given as `{name, beats}` is a note, and as `{:r, beats}` a rest."
  def seq(items) when is_list(items), do: %Seq{items: Enum.map(items, &item/1)}

  @doc "Music played one item after another, each the music the function returns for an item of the collection."
  def seq(collection, fun), do: seq(collected("seq", collection, fun))

  @doc "Music whose items all start at once, as long as the longest, refusing two parts of one name among them."
  def together(items) when is_list(items) do
    case Enum.find(items, &match?({name, music} when is_atom(name) and not is_number(music), &1)) do
      nil ->
        :ok

      {name, _music} ->
        raise ArgumentError,
              "together takes part names only in a module that uses Mx.Song; write part(:#{name}, music, synth: ...)"
    end

    items = Enum.map(items, &item/1)

    twice =
      items
      |> Enum.flat_map(&Enum.uniq(part_names(&1)))
      |> Enum.frequencies()
      |> Enum.find(fn {_name, count} -> count > 1 end)

    case twice do
      nil -> %Together{items: items}
      {name, _} -> raise ArgumentError, "two parts named #{name} play together"
    end
  end

  @doc "Music played one section after another, each the music the function returns for a section's name, or for its name and a map of its `pass`, `time` and `coming`; `round: true` gives the last section the first one's name as `coming`."
  def form(sections, fun, opts \\ [])

  def form([_ | _] = sections, fun, opts) when is_function(fun, 1) or is_function(fun, 2) do
    check_keyword("form", opts)

    case Keyword.keys(opts) -- [:round] do
      [] -> :ok
      [key | _] -> raise ArgumentError, "form takes round:, not #{key}:"
    end

    names = Enum.flat_map(sections, &form_names/1)
    comings = tl(names) ++ [if(opts[:round], do: hd(names))]

    {items, _times} =
      names
      |> Enum.zip(comings)
      |> Enum.with_index()
      |> Enum.map_reduce(%{}, fn {{name, coming}, pass}, times ->
        time = Map.get(times, name, 0)

        item =
          if is_function(fun, 1) do
            fun.(name)
          else
            fun.(name, %{pass: pass, time: time, coming: coming})
          end

        {item, Map.put(times, name, time + 1)}
      end)

    seq(items)
  end

  def form(sections, fun, _opts) do
    given = inspect({sections, fun})

    raise ArgumentError,
          "form takes a list of sections and a function of one or two arguments, not #{given}"
  end

  defp form_names({name, count}) when is_atom(name) and is_integer(count) and count >= 1 do
    List.duplicate(name, count)
  end

  defp form_names(name) when is_atom(name), do: [name]

  defp form_names({name, count}) when is_atom(name) do
    count = inspect(count)

    raise ArgumentError,
          "form takes section names, or names with counts from 1 up, not #{name}: #{count}"
  end

  defp form_names(entry) do
    entry = inspect(entry)
    raise ArgumentError, "form takes section names, or names with counts from 1 up, not #{entry}"
  end

  @doc "Music whose items all start at once, each the music the function returns for an item of the collection."
  def together(collection, fun), do: together(collected("together", collection, fun))

  defp collected(_name, collection, fun) when is_function(fun, 1), do: Enum.map(collection, fun)

  defp collected(name, _collection, other) do
    other = inspect(other)

    raise ArgumentError,
          "#{name} takes a list of music, or a collection and a function of one argument that makes each item, not #{other}"
  end

  @doc "The music after some beats of silence."
  def delay(music, beats) do
    check_beats("delay", beats)
    %Seq{items: [%Rest{beats: beats}, item(music)]}
  end

  @doc "Music played a number of times in a row."
  def repeat(music, times) when is_integer(times) and times > 0 do
    %Repeat{music: item(music), times: times}
  end

  def repeat(_music, times) do
    times = inspect(times)
    raise ArgumentError, "repeat takes a number of times from 1 up, not #{times}"
  end

  @doc "Music played again and again until mx stops."
  def repeat(music), do: %Repeat{music: item(music), times: :forever}

  @doc "The music moved by a number of semitones, every note moved and nothing else changed."
  def transpose(music, semitones) when is_number(semitones) do
    map_notes(item(music), fn
      %Note{pitch: :own_note} = note ->
        note

      %Note{pitch: pitches} = note when is_list(pitches) ->
        %{note | pitch: Enum.map(pitches, &(&1 + semitones))}

      %Note{pitch: pitch} = note ->
        %{note | pitch: pitch + semitones}
    end)
  end

  @doc "The music with the parts named left out, one name or a list, each as long a silence as it played, its tempo changes kept."
  def without(music, names), do: leave_out("without", music, List.wrap(names), &(&1 in &2))

  @doc "The music with every part but those named left out, one name or a list, each as long a silence as it played, its tempo changes kept."
  def only(music, names), do: leave_out("only", music, List.wrap(names), &(&1 not in &2))

  defp leave_out(word, music, names, out?) do
    music = item(music)
    have = part_names(music)

    case Enum.find(names, &(&1 not in have)) do
      nil -> :ok
      name -> raise ArgumentError, "#{word} names part #{name}, which the music does not have"
    end

    left_out(music, &out?.(&1, names)) || %Seq{items: []}
  end

  # nil for music that is gone, as a part left out that never ends is.
  defp left_out(%Part{name: name, music: music} = part, out?) do
    if out?.(name), do: silence(music), else: %{part | music: left_out(music, out?)}
  end

  defp left_out(%Seq{items: items} = seq, out?) do
    %{seq | items: kept(items, &left_out(&1, out?))}
  end

  defp left_out(%Together{items: items} = together, out?) do
    %{together | items: kept(items, &left_out(&1, out?))}
  end

  defp left_out(%At{entries: entries} = at, out?) do
    %{at | entries: kept_entries(entries, &left_out(&1, out?))}
  end

  defp left_out(%Repeat{music: music} = repeat, out?), do: kept_in(repeat, left_out(music, out?))
  defp left_out(%Swing{music: music} = swing, out?), do: kept_in(swing, left_out(music, out?))
  defp left_out(%Each{music: music} = each, out?), do: kept_in(each, left_out(music, out?))
  defp left_out(%Feel{music: music} = feel, out?), do: kept_in(feel, left_out(music, out?))

  defp left_out(%Loop{fun: fun} = loop, out?) do
    %{loop | fun: fn pass, inputs -> left_out(returned(fun.(pass, inputs)), out?) || %Seq{} end}
  end

  defp left_out(music, _out?), do: music

  # A part's music as silence of its length, with its tempo changes where they were.
  defp silence(%TempoChange{} = change), do: change
  defp silence(%Rest{} = rest), do: rest
  defp silence(%Part{music: music}), do: silence(music)
  defp silence(%Seq{items: items} = seq), do: %{seq | items: kept(items, &silence/1)}

  defp silence(%Together{items: items} = together) do
    %{together | items: kept(items, &silence/1)}
  end

  defp silence(%At{entries: entries} = at), do: %{at | entries: kept_entries(entries, &silence/1)}
  defp silence(%Repeat{music: music} = repeat), do: kept_in(repeat, silence(music))
  defp silence(%Swing{music: music}), do: silence(music)
  defp silence(%Each{music: music}), do: silence(music)
  defp silence(%Feel{music: music}), do: silence(music)

  defp silence(music) do
    case beats(music) do
      beats when is_number(beats) -> %Rest{beats: beats}
      :infinity -> nil
    end
  end

  defp kept(items, fun), do: items |> Enum.map(fun) |> Enum.reject(&is_nil/1)

  defp kept_entries(entries, fun) do
    for {beat, music} <- entries, kept = fun.(music), do: {beat, kept}
  end

  defp kept_in(_container, nil), do: nil
  defp kept_in(container, music), do: %{container | music: music}

  @doc "Music lasting some beats whose items start at their beats from its start, given as `{beat, music}`, or as `{beat, pitch, length}` and `{beat, pitch, length, options}` for a note."
  def at(entries, beats) when is_list(entries), do: at(entries, beats, [])

  @doc "Music lasting some beats with, at each beat of the entries given as `{beat, value}`, the music the function returns for the value, or with the options given to each note written as `{beat, pitch, length}`, its own options kept over them."
  def at(entries, beats, opts) when is_list(entries) and is_list(opts) do
    check_beats("at", beats)
    check_keyword("at", opts)

    entries =
      entries
      |> Enum.map(&noted(&1, opts))
      |> Enum.map(fn
        {beat, music} when is_number(beat) and beat >= 0 and beat < beats ->
          {beat, item(music)}

        {beat, _music} when is_number(beat) and beat >= 0 ->
          raise ArgumentError, "at places music at beat #{beat}, past its length of #{beats}"

        entry ->
          entry = inspect(entry)
          raise ArgumentError, "at takes {beat, music} from beat 0 up, not #{entry}"
      end)

    %At{entries: entries, beats: beats}
  end

  def at(entries, beats, fun) when is_function(fun, 1) do
    entries =
      Enum.map(entries, fn
        {beat, value} -> {beat, fun.(value)}
        entry -> entry
      end)

    at(entries, beats)
  end

  def at(_entries, _beats, other) do
    other = inspect(other)

    raise ArgumentError,
          "at takes {beat, value} entries, a length and a function of one argument that makes the music at each beat, or options for its notes, not #{other}"
  end

  defp noted({beat, pitch, length} = entry, opts) when is_number(beat) and beat >= 0 do
    placed(entry, beat, pitch, length, opts, [])
  end

  defp noted({beat, pitch, length, own} = entry, opts) when is_number(beat) and beat >= 0 do
    placed(entry, beat, pitch, length, opts, own)
  end

  defp noted(entry, _opts), do: entry

  defp placed(entry, beat, pitch, length, opts, own) do
    written = inspect(entry)

    if not (is_number(length) and length >= 0) do
      raise ArgumentError, "at plays a note for a length from 0 up, not #{written}"
    end

    check_keyword("at's note #{written}", own)

    try do
      {beat, note(pitch, length, own ++ Keyword.drop(opts, Keyword.keys(own)))}
    rescue
      error in ArgumentError ->
        reason = Exception.message(error)
        reraise ArgumentError, [message: "at cannot play #{written}: #{reason}"], __STACKTRACE__
    end
  end

  @doc "The music with each note started at the beat the function returns for the beat it was written on, its length unchanged."
  def swing(music, fun) when is_function(fun, 1), do: %Swing{music: item(music), fun: fun}

  @doc "Notes one after another as one note, of the first note's pitch and options, lasting them all and changing to each later note's pitch at its beat, gliding over slide: beats; a rest, or a note tongue: returns true for, starts a new one."
  def slur(music, opts \\ []) do
    check_keyword("slur", opts)
    {tongue, opts} = Keyword.pop(opts, :tongue)

    if tongue != nil and not is_function(tongue, 3) do
      tongue = inspect(tongue)

      raise ArgumentError,
            "slur takes tongue: as a function of the beat, the pitch before and the pitch, not #{tongue}"
    end

    {slide, opts} = Keyword.pop(opts, :slide)

    case runs(slurred(item(music)), tongue) do
      [[%Note{} | _] = run] -> slurred_note(run, slide, opts)
      runs -> %Seq{items: Enum.map(runs, &slurred_run(&1, slide, opts))}
    end
  end

  defp slurred_run(%Rest{} = rest, _slide, _opts), do: rest
  defp slurred_run(run, slide, opts), do: slurred_note(run, slide, opts)

  # The notes one after another as runs to slur and rests between them; a rest ends a run, and so
  # does a note that tongue: says the player starts afresh.
  defp runs(items, tongue) do
    {runs, run, _beat} =
      Enum.reduce(items, {[], [], 0}, fn
        %Rest{beats: beats} = rest, {runs, run, beat} ->
          {[rest | closed(run, runs)], [], beat + beats}

        note, {runs, [], beat} ->
          {runs, [note], beat + note.beats}

        note, {runs, [previous | _] = run, beat} ->
          if tongue && tongue.(beat, previous.pitch, note.pitch) == true do
            {closed(run, runs), [note], beat + note.beats}
          else
            {runs, [note | run], beat + note.beats}
          end
      end)

    Enum.reverse(closed(run, runs))
  end

  defp closed([], runs), do: runs
  defp closed(run, runs), do: [Enum.reverse(run) | runs]

  defp slurred_note([first | rest] = notes, slide, opts) do
    beats = notes |> Enum.map(& &1.beats) |> Enum.sum()

    {own, _} =
      Enum.map_reduce(rest, {first.beats, first.pitch}, fn note, {beat, previous} ->
        change =
          if note.pitch == previous do
            []
          else
            [{beat, [note: note.pitch] ++ slid(slide, previous, note.pitch)}]
          end

        {change, {beat + note.beats, note.pitch}}
      end)

    merged = Keyword.merge(first.opts, opts)
    changes = Enum.sort_by(Enum.concat(own) ++ Keyword.get(merged, :changes, []), &elem(&1, 0))

    merged =
      cond do
        Keyword.has_key?(merged, :changes) ->
          Enum.map(merged, fn
            {:changes, _} -> {:changes, changes}
            other -> other
          end)

        changes != [] ->
          merged ++ [changes: changes]

        true ->
          merged
      end

    note(first.pitch, beats, merged)
  end

  defp slurred(%Seq{items: items}), do: Enum.flat_map(items, &slurred/1)

  defp slurred(%Repeat{music: music, times: times}) when is_integer(times) do
    Enum.flat_map(1..times//1, fn _ -> slurred(music) end)
  end

  defp slurred(%Note{pitch: pitch} = note) when is_number(pitch), do: [note]
  defp slurred(%Rest{} = rest), do: [rest]

  defp slurred(other) do
    found =
      case other do
        %struct{} = written when struct in [Note, Sample, MIDI, Message] -> written(written)
        %Together{} -> "notes together"
        %Part{name: name} -> "the part #{name}"
        other -> inspect(other)
      end

    raise ArgumentError, "slur takes notes and rests one after another, not #{found}"
  end

  defp slid(nil, _from, _to), do: []
  defp slid(slide, from, to) when is_function(slide, 2), do: [note_slide: slide.(from, to)]
  defp slid(slide, _from, _to), do: [note_slide: slide]

  @feel_options [:step, :push, :lean, :loose, :touch]

  @doc "The music with each note on a step pushed and leaned by the tables given, and moved a little at random by loose: and touch:."
  def feel(music, opts) do
    check_keyword("feel", opts)

    case Enum.find(Keyword.keys(opts), &(&1 not in @feel_options)) do
      nil ->
        :ok

      name ->
        raise ArgumentError, "feel takes step:, push:, lean:, loose: and touch:, not #{name}:"
    end

    step = Keyword.get(opts, :step)

    cond do
      step == nil ->
        raise ArgumentError, "feel takes step:, the length of a step in beats"

      not (is_number(step) and step > 0) ->
        step = inspect(step)
        raise ArgumentError, "feel takes a step: above 0, not step: #{step}"

      true ->
        :ok
    end

    for name <- [:push, :lean], Keyword.has_key?(opts, name) do
      table = opts[name]

      if not (is_list(table) and table != [] and Enum.all?(table, &is_number/1)) do
        table = inspect(table)

        raise ArgumentError,
              "feel takes #{name}: as a list of numbers, a number to each step, not #{name}: #{table}"
      end
    end

    for name <- [:loose, :touch], Keyword.has_key?(opts, name) do
      amount = opts[name]

      if not (is_number(amount) and amount >= 0) do
        amount = inspect(amount)
        raise ArgumentError, "feel takes #{name}: as a number from 0 up, not #{name}: #{amount}"
      end
    end

    struct!(Feel, [music: item(music)] ++ opts)
  end

  @doc "The music with each of its notes and hits taking the options given, or those the function returns for the beat it starts on, where the note gives none of its own."
  def each(music, opts) when is_list(opts) or is_function(opts, 1) do
    if is_list(opts), do: check_keyword("each", opts)
    %Each{music: each_loop(item(music), opts), opts: opts}
  end

  def each(_music, other) do
    other = inspect(other)
    raise ArgumentError, "each takes a list of options or a function of a beat, not #{other}"
  end

  # The music a loop returns takes the options too, each pass counted from its own start.
  defp each_loop(%Loop{fun: fun} = loop, opts) do
    %{loop | fun: fn pass, inputs -> %Each{music: returned(fun.(pass, inputs)), opts: opts} end}
  end

  defp each_loop(music, opts) do
    map_notes(music, & &1, fn child, _ -> each_loop(child, opts) end)
  end

  # held: and sustain: both say how long a note sounds, so a note giving either takes neither.
  defp each_opts(%Note{opts: own} = note, opts) do
    sounds? = Keyword.has_key?(own, :sustain) or Keyword.has_key?(own, :held)

    added =
      for {name, value} <- opts,
          not Keyword.has_key?(own, name),
          not (sounds? and name in [:sustain, :held]),
          do: {name, value}

    %{note | opts: own ++ added}
  end

  @steps_options [:sample, :digit, :strokes, :notes, :words, :each, :slide, :accent, :grace]

  @doc "The sounds of a pattern, each character of a string or each word of `~MX` lasting a step of beats; a list of strings is one bar after another."
  def steps(pattern, step, opts \\ [])
      when (is_binary(pattern) or is_list(pattern)) and is_list(opts) do
    check_beats("steps", step)
    check_keyword("steps", opts)
    {own, each} = Keyword.split(opts, @steps_options)

    all = pattern |> List.wrap() |> Enum.flat_map(&cells/1) |> glided()

    if own[:words] && Enum.any?(all, &Map.get(&1, :char)) do
      raise ArgumentError,
            "steps' words: goes with a pattern read a word to a step, not a character to a step"
    end

    {cells, graces} = Enum.split_with(all, &(not Map.get(&1, :grace, false)))

    {items, _} =
      Enum.map_reduce(cells, 0, fn cell, at ->
        {cell_item(cell, at, step, own, each, nil), at + cell.steps}
      end)

    case graces do
      [] -> %Seq{items: items}
      _ -> graced(items, all, step, own, each)
    end
  end

  # Grace notes take no step: each starts grace: beats before the next, and the last of a run
  # grace: beats before the word that follows it, beside the words, which play as they would
  # without them.
  defp graced(items, cells, step, own, each) do
    grace = own[:grace] || 0.06
    check_beats("steps' grace:", grace)

    {entries, _} =
      cells
      |> Enum.chunk_by(&Map.get(&1, :grace, false))
      |> Enum.flat_map_reduce(0, fn
        [%{grace: true} | _] = run, at ->
          count = length(run)

          entries =
            for {cell, index} <- Enum.with_index(run) do
              beat = at * step - (count - index) * grace

              if beat < 0 do
                word = "^" <> Enum.join(cell.tokens, "/")

                raise ArgumentError,
                      "steps plays the grace note #{word} before the pattern starts; start the pattern with a silence"
              end

              {beat, cell_item(cell, at, step, own, each, grace)}
            end

          {entries, at}

        words, at ->
          {[], at + Enum.sum(Enum.map(words, & &1.steps))}
      end)

    seq = %Seq{items: items}
    %Together{items: [seq, %At{entries: entries, beats: beats(seq)}]}
  end

  @doc false
  def pattern_cells(pattern), do: pattern |> List.wrap() |> Enum.flat_map(&cells/1)

  defp cells(%{tokens: tokens, steps: steps} = cell) when is_list(tokens) and is_number(steps) do
    [cell]
  end

  defp cells(bars) when is_list(bars), do: Enum.flat_map(bars, &cells/1)

  defp cells(text) when is_binary(text), do: Mx.Pattern.parse_steps(text)

  defp cells(other) do
    other = inspect(other)
    raise ArgumentError, "steps takes a string, a list of strings or a ~MX pattern, not #{other}"
  end

  # A word that glides joins the note before it: the note lasts through it, and changes to its
  # pitch where it starts.
  defp glided(cells) do
    cells
    |> Enum.reduce([], fn
      %{glide: true, tokens: [token], steps: steps}, [%{tokens: [_]} = held | before] ->
        glides = Map.get(held, :glides, []) ++ [{held.steps, token}]
        [held |> Map.put(:glides, glides) |> Map.put(:steps, held.steps + steps) | before]

      %{glide: true, tokens: tokens}, _cells ->
        raise ArgumentError, "~#{Enum.join(tokens, "/")} glides from one note to one note"

      cell, cells ->
        [cell | cells]
    end)
    |> Enum.reverse()
  end

  defp cell_item(%{tokens: [], steps: steps}, _at, step, _own, _each, _beats) do
    %Rest{beats: steps * step}
  end

  defp cell_item(%{tokens: tokens, steps: steps} = cell, at, step, own, each, beats) do
    beats = beats || steps * step

    each =
      case own[:each] do
        nil -> each
        fun when is_function(fun, 1) -> each ++ fun.(at)
        fun when is_function(fun, 2) -> each ++ fun.(at, steps)
      end

    slide = if own[:slide], do: [note_slide: own[:slide]], else: []

    changes =
      for {after_steps, token} <- Map.get(cell, :glides, []) do
        {after_steps * step, [note: pitched(token, own)] ++ slide}
      end

    accented = accented(cell, own[:accent])

    case Enum.map(tokens, &sound(&1, own)) do
      [{:hit, opts}] when changes == [] ->
        stroke(own[:sample], beats, accented.(opts ++ each))

      [{:hit, _opts}] ->
        raise ArgumentError, "steps glides from a note, not from the stroke #{hd(tokens)}"

      [{:note, pitch}] when changes == [] ->
        note(pitch, beats, accented.(each))

      [{:note, pitch}] ->
        note(pitch, beats, accented.(each) ++ [changes: changes])

      sounds ->
        together_item(sounds, tokens, own[:sample], beats, accented, each)
    end
  end

  defp together_item(sounds, tokens, sample, beats, accented, each) do
    case Enum.split_with(sounds, &match?({:hit, _}, &1)) do
      {hits, []} ->
        together(for {:hit, opts} <- hits, do: stroke(sample, beats, accented.(opts ++ each)))

      {[], notes} ->
        note(List.flatten(Keyword.values(notes)), beats, accented.(each))

      _ ->
        word = Enum.join(tokens, "/")
        raise ArgumentError, "steps cannot play a stroke and a note together, as in #{word}"
    end
  end

  # What an accent does to a sound's options: a number is added to its vel, up to 1, and a list
  # takes the place of its options of the same names.
  defp accented(%{accent: true, tokens: tokens}, accent) do
    word = ">" <> Enum.join(tokens, "/")

    case accent do
      nil ->
        raise ArgumentError, "steps plays the accented word #{word} and has no accent:"

      amount when is_number(amount) ->
        fn opts ->
          case Keyword.fetch(opts, :vel) do
            {:ok, vel} ->
              Keyword.replace(opts, :vel, min(vel + amount, 1))

            :error ->
              raise ArgumentError,
                    "steps adds accent: #{amount} to the vel of #{word}, which has no vel"
          end
        end

      replaced when is_list(replaced) ->
        check_keyword("accent:", replaced)

        fn opts ->
          Enum.reduce(replaced, opts, fn {name, value}, opts ->
            if Keyword.has_key?(opts, name) do
              Keyword.replace(opts, name, value)
            else
              opts ++ [{name, value}]
            end
          end)
        end

      other ->
        other = inspect(other)
        raise ArgumentError, "steps takes accent: as a number or a list of options, not #{other}"
    end
  end

  defp accented(_cell, _accent), do: & &1

  defp stroke(nil, beats, opts), do: %Note{pitch: :own_note, beats: beats, opts: opts}
  defp stroke(ref, beats, opts), do: sample(ref, beats, opts)

  # What a character or a word sounds: a stroke of strokes:, a pitch of words:, x, a digit as a
  # note of notes: or as a level, or else a note's name.
  defp sound(token, own) do
    stroke = named_in(own[:strokes], token)
    digit = if token =~ ~r/^[0-9]$/, do: String.to_integer(token)

    cond do
      stroke ->
        {:hit, elem(stroke, 1)}

      named_in(own[:words], token) ->
        {:note, pitched(token, own)}

      token == "x" ->
        {:hit, []}

      digit && own[:notes] ->
        case digit > 0 && Enum.at(own[:notes], digit - 1) do
          found when found in [nil, false] ->
            raise ArgumentError, "steps has no note #{token} in notes:"

          found ->
            {:hit, [note: pitch(found)]}
        end

      digit ->
        {:hit, [{own[:digit] || if(own[:sample], do: :amp, else: :vel), digit / 9}]}

      true ->
        {:note, named(token)}
    end
  end

  defp named_in(list, token) do
    Enum.find(list || [], fn {name, _} -> to_string(name) == token end)
  end

  defp pitched(token, own) do
    case named_in(own[:words], token) do
      {_word, pitch} -> pitch(pitch)
      nil -> named(token)
    end
  end

  defp named(token) do
    Notes.parse(token)
  rescue
    ArgumentError ->
      reraise ArgumentError,
              [
                message:
                  "steps takes x, a digit, a stroke of strokes:, a word of words: or a note's name, and . for silence, not #{token}"
              ],
              __STACKTRACE__
  end

  @doc "Music that runs the function with the pass number and the inputs every `beats` beats, and plays the music it returns; `times:` plays a number of passes, and `on:`, given instead of beats, plays a pass on each input it waits for, on the next beat that is a multiple of `grid:` beats when given."
  def loop(beats, fun, opts \\ [])

  def loop(beats, fun, opts) when is_number(beats) and is_function(fun, 2) and is_list(opts) do
    if beats <= 0, do: raise(ArgumentError, "loop takes a length in beats above 0, not #{beats}")

    case Enum.find(Keyword.keys(opts), &(&1 != :times)) do
      nil ->
        :ok

      :on ->
        raise ArgumentError,
              "a loop started by on: has no length; write loop(fn trigger, inputs -> music end, on: :midi_note)"

      option ->
        raise ArgumentError, "loop has no option #{option}"
    end

    case opts[:times] do
      times when is_nil(times) or (is_integer(times) and times > 0) ->
        %Loop{beats: beats, fun: fun, times: times, line: fun_line(fun)}

      times ->
        times = inspect(times)
        raise ArgumentError, "loop takes times: from 1 up, not #{times}"
    end
  end

  def loop(fun, opts, []) when is_function(fun, 2) and is_list(opts) do
    on = opts[:on]

    if not (on in [:midi_note, :midi_cc] or match?({:osc, address} when is_binary(address), on)) do
      on = inspect(on)

      raise ArgumentError,
            "a loop with no length takes on: :midi_note, :midi_cc or {:osc, address}, not #{on}"
    end

    %Loop{fun: fun, on: on, grid: opts[:grid], line: fun_line(fun)}
  end

  # The line of a function written at the top of the song, which keeps its line as it is
  # evaluated; a function of a module keeps none.
  defp fun_line(fun) do
    with {:module, :erl_eval} <- Function.info(fun, :module),
         {:env, [entry | _]} when is_tuple(entry) <- Function.info(fun, :env) do
      :erl_anno.line(elem(entry, 0))
    else
      _ -> nil
    end
  end

  @doc "Music played by one player, refusing a synth mx does not have and a note the synth cannot play."
  def part(name, music, opts \\ []) when is_atom(name) and is_list(opts) do
    if name == :song do
      raise ArgumentError,
            "a part cannot be named song: the name is taken by the song's own chain, the effects of its fx:"
    end

    case Enum.find(Keyword.keys(opts), &(&1 not in @part_options)) do
      nil -> :ok
      option -> raise ArgumentError, "part #{name} has no option #{option}"
    end

    part = struct(%Part{name: name, music: item(music)}, opts)

    case part_names(part.music) do
      [] ->
        :ok

      inner ->
        inner = inner |> Enum.uniq() |> Enum.join(", ")

        raise ArgumentError,
              "part #{name} holds the parts #{inner}; a kit plays beside parts, in together, not inside a part"
    end

    part = %{part | synth: load_sampled(name, part.synth)}
    synth = part.synth

    if not Synths.exists?(synth) do
      raise ArgumentError, "part #{name} uses synth #{synth}, which mx does not have"
    end

    check_defaults(part)

    case Mx.Song.check_fx(part.fx) do
      :ok -> :ok
      {:error, message} -> raise ArgumentError, "part #{name}: #{message}"
    end

    for note <- own_notes(part.music), do: check_note!(part, note)

    part
  end

  defp load_sampled(name, %Mx.Sampled{} = sampled) do
    case Mx.Sampled.load(sampled) do
      {:ok, sampled} -> sampled
      {:error, message} -> raise ArgumentError, "part #{name}: #{message}"
    end
  end

  defp load_sampled(_name, synth), do: synth

  defp check_defaults(%Part{name: name, synth: synth, defaults: defaults}) do
    if not Keyword.keyword?(defaults) do
      raise ArgumentError,
            "part #{name}: defaults: takes a list of options, such as defaults: [amp: 0.5]"
    end

    case Enum.find(Keyword.keys(defaults), &(not Synths.option?(synth, &1))) do
      nil -> :ok
      option -> raise ArgumentError, "part #{name}: synth #{synth} has no option #{option}"
    end

    case check_values(synth, defaults) do
      :ok -> :ok
      {:error, message} -> raise ArgumentError, "part #{name}: #{message}"
    end
  end

  defp check_values(synth, opts) do
    Enum.find_value(opts, :ok, fn {option, value} ->
      case Synths.check_value(synth, option, value) do
        :ok -> nil
        error -> error
      end
    end)
  end

  @doc "The song, refusing a note outside any part, a part of one name played with other options, and repeat with no count anywhere but around the whole music."
  def song(opts) when is_list(opts) do
    check_options(opts)
    music = item(opts[:music])
    {sections, forever} = sections(music)
    lengths = Enum.map(sections, &beats/1)

    check_endless(Enum.reject(lengths, &(&1 == 0)), forever)
    played = Enum.zip_with(sections, lengths, &flatten(&1, 0, nil, &2))
    {played, changes} = played |> Enum.map(&split_tempos/1) |> Enum.unzip()
    changes = carry_tempos(changes, lengths)
    {played, triggered} = Enum.map_reduce(played, [], &split_triggered/2)

    buses =
      case Mx.Song.buses(Keyword.get(opts, :buses, [])) do
        {:ok, buses} -> buses
        {:error, message} -> raise ArgumentError, message
      end

    played = route_changes(played, triggered, Keyword.get(opts, :fx, []), buses)
    check_osc_to(played, opts[:osc_to])

    {played, lengths, changes} =
      [played, lengths, changes]
      |> Enum.zip()
      |> Enum.reject(&(elem(&1, 1) == 0))
      |> unzip3()

    if played == [] and triggered == [] do
      raise(ArgumentError, "the song's music lasts no time")
    end

    parts =
      for part <- parts(played ++ [triggered]) do
        case Enum.filter(triggered, fn {_, %Part{name: name}, _} -> name == part.name end) do
          [] ->
            {part, part_sections(part, played, lengths)}

          [{_, _, {:triggered, loop}}] ->
            if Enum.any?(List.flatten(played), fn {_, %Part{name: name}, _} ->
                 name == part.name
               end) do
              raise ArgumentError,
                    "part #{part.name} plays a loop started by on:, so it can play no other music"
            end

            grid = loop.grid

            if grid != nil and not (is_number(grid) and grid > 0) do
              grid = inspect(grid)
              raise ArgumentError, "loop #{part.name} takes grid: in beats above 0, not #{grid}"
            end

            {part, {:triggered, loop.on, loop.fun, loop.line, grid}}

          _ ->
            raise ArgumentError, "part #{part.name} has more than one loop started by on:"
        end
      end

    tempos =
      if Enum.any?(changes, &(&1 != [])) do
        %{
          sections: List.to_tuple(changes),
          lengths: List.to_tuple(lengths),
          forever: forever
        }
      end

    parts = send_parts(parts, played, buses)
    song = %Song{music: music, sections: length(played), parts: parts, forever: forever}
    %{struct(song, opts) | tempos: tempos, buses: buses}
  end

  # Each part with its sends checked against the song's buses, and a send at 0 for each bus a
  # change of the part names, which a loop started by on: has for every bus, as its changes are
  # not known yet.
  defp send_parts(parts, played, buses) do
    names = Enum.map(buses, & &1.name)
    part_names = for {part, _music} <- parts, do: part.name
    keys = names ++ part_names

    for bus <- buses do
      with message when message != nil <- Mx.Song.keys_error("bus #{bus.name}", bus.fx, keys) do
        raise ArgumentError, message
      end
    end

    changed =
      for {_, %Part{name: name}, %Change{target: name, opts: opts}} <- List.flatten(played),
          {bus, _level} <- Keyword.get(opts, :send, []),
          do: {name, bus}

    for {part, music} <- parts do
      if part.name in names do
        raise ArgumentError,
              "#{part.name} is the name of a part and of a bus, and a change could not tell them apart"
      end

      with message when message != nil <-
             Mx.Song.sends_error("part #{part.name}", part.send, names) do
        raise ArgumentError, message
      end

      with message when message != nil <-
             Mx.Song.keys_error("part #{part.name}", part.fx, keys) do
        raise ArgumentError, message
      end

      later =
        if match?({:triggered, _, _, _, _}, music) do
          names
        else
          for {name, bus} <- changed, name == part.name, do: bus
        end

      zero = for bus <- Enum.uniq(later), not Keyword.has_key?(part.send, bus), do: {bus, 0}
      {%{part | send: part.send ++ zero}, music}
    end
  end

  defp check_options(opts) do
    case Enum.find(Keyword.keys(opts), &(&1 not in @song_options)) do
      nil -> :ok
      option -> raise ArgumentError, "song has no option #{option}"
    end

    if not Keyword.has_key?(opts, :music) do
      raise ArgumentError, "song takes its music with music: ..."
    end

    case Keyword.get(opts, :meter, 4) do
      meter when is_integer(meter) and meter > 0 ->
        :ok

      meter ->
        meter = inspect(meter)
        raise ArgumentError, "song takes meter: as whole beats to a bar above 0, not #{meter}"
    end

    case opts[:key] do
      nil ->
        :ok

      key when is_atom(key) ->
        with {:error, _} <- key |> Atom.to_string() |> Mx.MusicXML.key(), do: refuse_key(key)

      key ->
        refuse_key(key)
    end

    with {:error, message} <- opts |> Keyword.get(:fx, []) |> Mx.Song.song_effects() do
      raise ArgumentError, message
    end

    case opts[:osc_to] do
      nil -> :ok
      {host, port} when is_binary(host) and is_integer(port) -> :ok
      other -> raise ArgumentError, "song takes osc_to: as {host, port}, not #{inspect(other)}"
    end
  end

  defp refuse_key(key) do
    key = inspect(key)
    raise ArgumentError, "song takes key: as a key such as :d, :bm or :fsm, not #{key}"
  end

  defp unzip3(triples) do
    {Enum.map(triples, &elem(&1, 0)), Enum.map(triples, &elem(&1, 1)),
     Enum.map(triples, &elem(&1, 2))}
  end

  # A section's tempo changes as {beat, bpm, over}, apart from its parts' notes.
  defp split_tempos(events) do
    {changes, events} = Enum.split_with(events, &match?({_, _, %TempoChange{}}, &1))

    changes =
      for {beat, _, change} <- Enum.sort_by(changes, &elem(&1, 0)),
          do: {beat, change.bpm, change.over}

    {events, changes}
  end

  # A tempo change in a section that takes no time, such as seq([tempo(140), section]), starts the
  # next section.
  defp carry_tempos(changes, lengths) do
    {carried, waiting} =
      changes
      |> Enum.zip(lengths)
      |> Enum.map_reduce([], fn
        {mine, 0}, waiting -> {[], waiting ++ mine}
        {mine, _length}, waiting -> {waiting ++ mine, []}
      end)

    if waiting != [] do
      raise ArgumentError,
            "a tempo change at the end of the music changes nothing; put it before the music it is for"
    end

    carried
  end

  defp check_endless(lengths, forever) do
    endless = Enum.find_index(lengths, &(&1 == :infinity))

    if endless != nil and (forever or endless != length(lengths) - 1) do
      raise ArgumentError,
            "a loop with no times: plays until mx stops, so beside only other loops it can only be in the song's last section"
    end
  end

  # A change plays in the part it names, wherever it is written.
  defp route_changes(played, triggered, song_fx, buses) do
    by_name =
      for {_, %Part{} = part, step} <- List.flatten([played, triggered]),
          not is_struct(step, Change),
          into: %{},
          do: {part.name, part}

    for events <- played do
      Enum.map(events, fn
        {beat, part, %Change{target: {:song, effect}} = change} ->
          {beat, song_changed(change, effect, part, by_name, song_fx), change}

        {beat, part, %Change{target: {name, effect}} = change}
        when not is_map_key(by_name, name) ->
          {beat, bus_changed(change, name, effect, part, by_name, buses), change}

        {beat, _part, %Change{} = change} ->
          {beat, changed_part(change, by_name, buses), change}

        event ->
          event
      end)
    end
  end

  # A change to one of the song's own effects plays in the part it is written in, or in the song's
  # first part.
  defp song_changed(%Change{opts: opts}, effect, part, by_name, song_fx) do
    {:ok, chain} = Mx.Song.song_effects(song_fx)

    if not List.keymember?(chain, effect, 0) do
      raise ArgumentError, "change names effect #{effect}, which the song's fx: does not have"
    end

    Pass.check_change({:effect, effect}, opts)
    written_in(part, by_name)
  end

  # A change to an effect of a bus plays in the part it is written in, or in the song's first
  # part.
  defp bus_changed(%Change{opts: opts}, name, effect, part, by_name, buses) do
    bus =
      Enum.find(buses, &(&1.name == name)) ||
        raise ArgumentError, "change names part #{name}, which the song does not have"

    if not List.keymember?(bus.fx, effect, 0) do
      raise ArgumentError, "change names effect #{effect}, which bus #{name} does not have"
    end

    Pass.check_change({:effect, effect}, opts)
    written_in(part, by_name)
  end

  defp written_in(part, by_name) do
    case {part, Enum.sort(Map.keys(by_name))} do
      {%Part{} = part, _names} -> part
      {_none, [first | _]} -> Map.fetch!(by_name, first)
      {_none, []} -> raise ArgumentError, "change needs a part playing in its section"
    end
  end

  defp changed_part(%Change{target: target, opts: opts}, by_name, buses) do
    {sends, opts} = Keyword.split(opts, [:send, :send_slide])
    {name, effect} = if is_atom(target), do: {target, nil}, else: target

    part =
      case by_name do
        %{^name => part} -> part
        _ -> raise ArgumentError, "change names part #{name}, which the song does not have"
      end

    names = Enum.map(buses, & &1.name)
    slide = Keyword.get(sends, :send_slide, 0)

    cond do
      effect != nil and sends != [] ->
        raise ArgumentError, "a change to an effect takes no send: or send_slide:"

      not (is_number(slide) and slide >= 0) ->
        slide = inspect(slide)
        raise ArgumentError, "change takes send_slide: in beats, 0 or more, not #{slide}"

      message =
          Mx.Song.sends_error("change of part #{name}", Keyword.get(sends, :send, []), names) ->
        raise ArgumentError, message

      effect == nil ->
        Pass.check_change(part.synth, opts)

      effect in Enum.map(List.wrap(part.fx), fn
        {name, _} -> name
        name -> name
      end) ->
        Pass.check_change({:effect, effect}, opts)

      true ->
        raise ArgumentError, "change names effect #{effect}, which part #{name} does not have"
    end

    part
  end

  defp check_osc_to(played, osc_to) do
    if osc_to == nil and
         played |> List.flatten() |> Enum.any?(&match?({_, _, %Message{kind: :osc}}, &1)) do
      raise ArgumentError, "osc needs osc_to: {host, port} in the song"
    end
  end

  defp split_triggered(events, triggered) do
    {now, timed} = Enum.split_with(events, &match?({_, _, {:triggered, _}}, &1))
    {timed, triggered ++ now}
  end

  # A part's notes and loops in each section, the length each section plays as a pass, and the
  # number of loop passes before each.
  defp part_sections(part, played, lengths) do
    held = held_share(part)

    sections =
      Enum.zip_with(played, lengths, fn events, length ->
        mine = Enum.filter(events, fn {_beat, %Part{name: name}, _} -> name == part.name end)

        notes = for {beat, _part, step} <- mine, is_struct(step), do: {beat, step}

        slots =
          for {beat, _part, {:loop, loop, cut}} <- mine do
            %{start: beat, beats: loop.beats, fun: loop.fun, cut: cut, line: loop.line}
          end

        window =
          if length == :infinity, do: slots |> Enum.map(& &1.beats) |> Enum.max(), else: length

        %{
          notes: Enum.sort_by(notes, &elem(&1, 0)),
          slots: slots,
          beats: window,
          endless: length == :infinity
        }
      end)

    counts = Enum.map(sections, &if(&1.endless, do: 0, else: passes_before(&1.slots, &1.beats)))
    prefix = [0 | counts] |> Enum.scan(&(&1 + &2)) |> Enum.drop(-1)

    steps = Enum.flat_map(sections, & &1.notes)
    samples = for {_, %Sample{ref: ref}} <- steps, uniq: true, do: ref

    %{
      name: part.name,
      held: held,
      changed: Enum.any?(steps, &match?({_, %Change{target: target}} when is_atom(target), &1)),
      samples: samples,
      sections: List.to_tuple(sections),
      prefix: List.to_tuple(prefix),
      cycle: Enum.sum(counts)
    }
  end

  # The number of passes the loops start before a beat.
  defp passes_before(slots, beat) do
    slots
    |> Enum.map(fn slot ->
      until = earlier(slot.cut, beat)
      if until > slot.start, do: ceil((until - slot.start) / slot.beats), else: 0
    end)
    |> Enum.sum()
  end

  defp earlier(:infinity, beat), do: beat
  defp earlier(beat, :infinity), do: beat
  defp earlier(beat, other), do: min(beat, other)

  @doc "The number of a note name, or the number itself."
  def pitch(pitches) when is_list(pitches), do: Enum.map(pitches, &pitch/1)

  def pitch(pitch)
      when is_number(pitch) or (is_atom(pitch) and pitch not in [nil, true, false]) do
    Notes.note(pitch)
  end

  def pitch(name) when is_binary(name), do: Notes.parse(name)

  def pitch(pitch) do
    pitch = inspect(pitch)
    raise ArgumentError, "a note is a name such as :c4 or a number, not #{pitch}"
  end

  @doc "The length of the music in beats, or `:infinity` for music that plays until mx stops."
  def beats(%Note{beats: beats}), do: beats
  def beats(%Rest{beats: beats}), do: beats
  def beats(%Sample{beats: beats}), do: beats
  def beats(%MIDI{beats: beats}), do: beats
  def beats(%Message{}), do: 0
  def beats(%Change{}), do: 0
  def beats(%TempoChange{}), do: 0
  def beats(%At{beats: beats}), do: beats
  def beats(%Swing{music: music}), do: beats(music)
  def beats(%Each{music: music}), do: beats(music)
  def beats(%Feel{music: music}), do: beats(music)
  def beats(%Part{music: music}), do: beats(music)
  def beats(%Repeat{times: :forever}), do: :infinity
  def beats(%Repeat{music: music, times: times}), do: times(beats(music), times)
  def beats(%Loop{on: on}) when on != nil, do: 0
  def beats(%Loop{times: nil}), do: :infinity
  def beats(%Loop{beats: beats, times: times}), do: beats * times
  def beats(%Seq{items: items}), do: Enum.reduce(items, 0, &plus(beats(&1), &2))

  # As long as the longest item that ends, so a loop with no end plays as long as the music beside
  # it; a loop started by on: has no length to end with.
  def beats(%Together{items: items}) do
    timed = Enum.reject(items, &triggered?/1)

    case timed |> Enum.map(&beats/1) |> Enum.reject(&(&1 == :infinity)) do
      [] when timed != [] -> :infinity
      ending -> Enum.max(ending, fn -> 0 end)
    end
  end

  def beats(music), do: music |> item() |> beats()

  defp triggered?(%Loop{on: on}), do: on != nil
  defp triggered?(%Part{music: music}), do: triggered?(music)
  defp triggered?(_music), do: false

  defp times(:infinity, _times), do: :infinity
  defp times(beats, times), do: beats * times

  defp plus(:infinity, _sum), do: :infinity
  defp plus(_beats, :infinity), do: :infinity
  defp plus(beats, sum), do: beats + sum

  @doc "Records a song into the song being loaded: its settings, and a loop for each of its parts."
  def load(%Song{} = song) do
    Mx.Song.put_tempo(song.tempo)
    Mx.Song.put_meter(song.meter)
    if song.key, do: Mx.Song.put_key(song.key)
    if song.tempos, do: Mx.Song.put_tempos(song.tempos)
    if song.osc_from, do: Mx.Song.put_osc_from(song.osc_from)
    with {host, port} <- song.osc_to, do: Mx.Song.put_osc_to(host, port)
    Mx.Song.put_fx(song.fx)
    Mx.Song.put_buses(song.buses)
    for {name, opts} <- song.live_audio, do: Mx.Song.put_live(name, opts)

    for {part, music} <- song.parts do
      case music do
        {:triggered, on, fun, line, grid} ->
          held = held_share(part)

          Mx.Song.put_music_loop(
            part,
            %{name: part.name, held: held, triggered: fun, line: line, grid: grid},
            nil,
            on
          )

        music ->
          endless = music.sections |> Tuple.to_list() |> Enum.any?(& &1.endless)
          passes = if song.forever or endless, do: nil, else: song.sections
          Mx.Song.put_music_loop(part, Map.put(music, :forever, song.forever), passes, nil)
      end
    end

    :ok
  end

  @doc "Records pass `n` of a part's music: its notes in section `n`, and the passes its loops play there, going round again after the last section of music that repeats until mx stops."
  def replay(%{triggered: fun} = music, pass) when is_integer(pass) do
    :rand.seed(:exsss, {:erlang.phash2(music.name), pass, 1})
    played = run_loop(music, music.line, fun, Pass.trigger())
    length = beats(played)
    record(music, flatten(played, 0, :loop, :infinity), 0, :infinity)
    Pass.record_wait(if(length > 0, do: length, else: 1))
    :ok
  end

  def replay(%{sections: sections} = music, pass) when is_integer(pass) do
    count = tuple_size(sections)

    {index, window, base} =
      cond do
        music.forever ->
          {rem(pass, count), 0,
           div(pass, count) * music.cycle + elem(music.prefix, rem(pass, count))}

        pass >= count - 1 and elem(sections, count - 1).endless ->
          {count - 1, pass - (count - 1), elem(music.prefix, count - 1)}

        true ->
          {min(pass, count - 1), 0, elem(music.prefix, min(pass, count - 1))}
      end

    section = elem(sections, index)
    from = window * section.beats
    until = from + section.beats

    if window == 0 do
      record(
        music,
        Enum.map(section.notes, fn {beat, step} -> {beat, nil, step} end),
        0,
        :infinity
      )
    end

    before = base + passes_before(section.slots, from)

    section.slots
    |> Enum.flat_map(fn slot ->
      first = if from > slot.start, do: ceil((from - slot.start) / slot.beats), else: 0

      for turn <-
            first
            |> Stream.iterate(&(&1 + 1))
            |> Enum.take_while(&(slot.start + &1 * slot.beats < earlier(slot.cut, until))),
          do: {slot.start + turn * slot.beats, slot}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.with_index(before)
    |> Enum.each(fn {{start, slot}, loop_pass} ->
      :rand.seed(:exsss, {:erlang.phash2(music.name), loop_pass, 1})
      played = run_loop(music, slot.line, slot.fun, loop_pass)
      length = beats(played)

      if length == :infinity or length > slot.beats do
        name = music.name
        made = format_beats(length)
        given = format_beats(slot.beats)

        raise LoopError,
          message: "loop #{name} made #{made} beats of music in a pass of #{given}",
          line: slot.line
      end

      record(
        music,
        flatten(played, start - from, :loop, :infinity),
        0,
        earlier(slot.cut, until) - from
      )
    end)

    Pass.record_wait(section.beats)
    :ok
  end

  # A function written at the top of the song runs evaluated, so an error in it carries no line of
  # the song; the loop's own line stands in.
  defp run_loop(music, line, fun, pass) do
    returned(fun.(pass, inputs()))
  rescue
    error ->
      called = Enum.take_while(__STACKTRACE__, &(not match?({Mx.Music, :run_loop, _, _}, &1)))

      if line == nil or Enum.any?(called, &song_frame?/1) do
        reraise error, __STACKTRACE__
      else
        name = music.name
        message = Exception.message(error)
        reraise LoopError, [message: "part #{name}: #{message}", line: line], __STACKTRACE__
      end
  end

  defp song_frame?({_, _, _, info}), do: String.ends_with?(to_string(info[:file]), ".exs")

  defp returned(played) do
    case played do
      %Part{} -> raise ArgumentError, "a loop's function returns music, not a part"
      %Loop{} -> raise ArgumentError, "a loop's function returns music, not a loop"
      %_{} = played -> item(played)
      played when is_list(played) -> item(played)
      other -> raise ArgumentError, "a loop's function returns music, not #{inspect(other)}"
    end
  end

  # Plays each note from its beat, leaving out the notes that start at or after a cut, and holding
  # a note its length where the synth takes sustain.
  defp record(music, events, offset, cut) do
    steps =
      for {beat, _part, step} <- events, cut == :infinity or beat + offset < cut do
        if is_tuple(step) do
          raise ArgumentError,
                "a loop's music holds notes, rests, seq, together, repeat, at, swing, steps, samples, MIDI, messages and changes, not parts or loops"
        end

        {beat + offset, step}
      end

    Pass.record_at(steps, fn {_beat, step} -> record_step(music, step) end)
  end

  defp record_step(music, %Note{} = note) do
    {changes, opts} = Keyword.pop(held_opts(music.held, note), :changes, [])
    handle = Pass.record_play(note.pitch, opts, Keyword.get(note.opts, :sustain, note.beats))
    Pass.record_at(changes, fn {_beat, opts} -> Pass.record_control(handle, opts) end)
  end

  defp record_step(_music, %Sample{ref: ref, opts: opts}), do: Pass.record_sample(ref, opts)

  defp record_step(_music, %MIDI{note: note, beats: beats, opts: opts}) do
    Pass.record_midi(note, [length: beats] ++ opts)
  end

  defp record_step(_music, %Message{kind: :midi_cc, args: [number, value, opts]}) do
    Pass.record_midi_cc(number, value, opts)
  end

  defp record_step(_music, %Message{kind: :osc, args: [address, args]}) do
    Pass.record_osc(address, args)
  end

  defp record_step(_music, %Message{kind: :set, args: [name, value]}) do
    Pass.record_set(name, value)
  end

  defp record_step(%{name: name}, %Change{target: name, opts: opts}) do
    {sends, opts} = Keyword.split(opts, [:send, :send_slide])
    if opts != [] or sends == [], do: Pass.record_change(opts)
    slide = Keyword.take(sends, [:send_slide])

    slides = for {_, beats} <- slide, do: {:level_slide, beats}

    for {bus, level} <- Keyword.get(sends, :send, []) do
      Pass.record_send(bus, [level: level] ++ slides)
    end

    :ok
  end

  defp record_step(_part, %Change{target: {:song, effect}, opts: opts}) do
    effect |> Pass.song_effect() |> Pass.record_control(opts)
  end

  defp record_step(%{name: name}, %Change{target: {name, effect}, opts: opts}) do
    effect |> Pass.effect() |> Pass.record_control(opts)
  end

  defp record_step(%{name: name}, %Change{target: {bus, effect}, opts: opts} = change) do
    case Pass.bus_effect(bus, effect) do
      nil -> refuse_change(name, change)
      handle -> Pass.record_control(handle, opts)
    end
  end

  defp record_step(%{name: name}, %Change{} = change), do: refuse_change(name, change)

  defp refuse_change(name, %Change{target: target}) do
    target = inspect(target)
    raise ArgumentError, "a loop's music changes only its own part #{name}, not #{target}"
  end

  # The share of its length a note sounds for when it gives no sustain: or held:, from the part's
  # defaults, or false where the synth takes no sustain or the defaults give one.
  defp held_share(part) do
    if Synths.option?(part.synth, :sustain) and not Keyword.has_key?(part.defaults, :sustain) do
      Keyword.get(part.defaults, :held, 1)
    else
      false
    end
  end

  # The first of a note's sustain: and held: decides; a held: becomes its share of the length.
  defp held_opts(share, %Note{opts: opts, beats: beats}) do
    case Enum.split_while(opts, &(elem(&1, 0) not in [:sustain, :held])) do
      {before, [{:held, held} | rest]} ->
        before ++ [{:sustain, held * beats}] ++ Keyword.drop(rest, [:sustain, :held])

      {_before, [{:sustain, _} | _]} ->
        Keyword.delete(opts, :held)

      {_opts, []} when share != false and beats > 0 ->
        opts ++ [sustain: share * beats]

      {_opts, []} ->
        opts
    end
  end

  defp format_beats(:infinity), do: "endless"
  defp format_beats(beats) when beats == trunc(beats), do: Integer.to_string(trunc(beats))
  defp format_beats(beats), do: to_string(beats)

  defp inputs do
    Enum.reduce(Pass.inputs(), %{cc: %{}, notes: %{}, osc: %{}, values: %{}}, fn
      {{:cc, number}, value}, inputs -> put_in(inputs.cc[number], value)
      {{:note, note}, velocity}, inputs -> put_in(inputs.notes[note], velocity)
      {{:osc, address}, args}, inputs -> put_in(inputs.osc[address], args)
      {{:value, name}, value}, inputs -> put_in(inputs.values[name], value)
      _, inputs -> inputs
    end)
  end

  defp sections(%Repeat{times: :forever, music: music}), do: {items(music), true}
  defp sections(music), do: {items(music), false}

  defp items(%Seq{items: items}), do: Enum.flat_map(items, &through_repeat/1)

  defp items(%Repeat{times: times, music: music}) when is_integer(times) do
    Enum.flat_map(1..times, fn _ -> items(music) end)
  end

  defp items(music), do: [music]

  defp through_repeat(%Repeat{times: times, music: music}) when is_integer(times) do
    Enum.flat_map(1..times, fn _ -> items(music) end)
  end

  defp through_repeat(music), do: [music]

  # Every note of the music as {beat, part, note}, and every loop as {beat, part, {:loop, loop,
  # cut}}, cut being the beat its last pass stops at.
  defp flatten(%Note{} = note, beat, part, _cut) do
    if part == nil do
      written = written(note)

      raise ArgumentError,
            "every note plays in a part; put #{written} in part(name, music, synth: ...)"
    end

    [{beat, part, note}]
  end

  defp flatten(%Change{} = change, beat, part, _cut), do: [{beat, part, change}]

  defp flatten(%TempoChange{}, _beat, :loop, _cut) do
    raise ArgumentError,
          "tempo changes every part, so it is written in the song's music, not returned by a loop"
  end

  defp flatten(%TempoChange{} = change, beat, _part, _cut), do: [{beat, nil, change}]

  defp flatten(%struct{} = step, beat, part, _cut) when struct in [Sample, MIDI, Message] do
    if part == nil do
      written = written(step)
      raise ArgumentError, "#{written} plays in a part; put it in part(name, music, ...)"
    end

    [{beat, part, step}]
  end

  defp flatten(%Loop{} = loop, beat, part, cut) do
    if part == nil do
      raise(ArgumentError, "every loop plays in a part; put it in part(name, loop, synth: ...)")
    end

    case loop do
      %Loop{on: on} when on != nil ->
        [{beat, part, {:triggered, loop}}]

      %Loop{times: nil} ->
        [{beat, part, {:loop, loop, cut}}]

      %Loop{times: times} ->
        [{beat, part, {:loop, loop, earlier(cut, beat + loop.beats * times)}}]
    end
  end

  defp flatten(%Rest{}, _beat, _part, _cut), do: []
  defp flatten(%Part{music: music} = part, beat, _part, cut), do: flatten(music, beat, part, cut)
  defp flatten(%Repeat{times: :forever}, _beat, _part, _cut), do: raise(ArgumentError, @forever)

  defp flatten(%Together{items: items} = together, beat, part, cut) do
    cut = earlier(cut, plus(beats(together), beat))
    Enum.flat_map(items, &flatten(&1, beat, part, cut))
  end

  defp flatten(%Seq{items: items}, beat, part, cut) do
    {events, _end} =
      Enum.flat_map_reduce(items, beat, fn
        _item, :infinity ->
          raise ArgumentError,
                "music after a loop with no times: never plays, since that loop plays until mx stops"

        item, start ->
          ends = plus(beats(item), start)
          {flatten(item, start, part, earlier(cut, ends)), ends}
      end)

    events
  end

  defp flatten(%Repeat{music: music, times: times}, beat, part, cut) do
    length = beats(music)

    Enum.flat_map(
      0..(times - 1),
      &flatten(music, beat + &1 * length, part, earlier(cut, beat + (&1 + 1) * length))
    )
  end

  defp flatten(%At{entries: entries, beats: length}, beat, part, cut) do
    Enum.flat_map(entries, fn {offset, music} ->
      flatten(music, beat + offset, part, earlier(cut, beat + length))
    end)
  end

  defp flatten(%Swing{music: music, fun: fun}, beat, part, cut) do
    for {written, part, note} <- flatten(music, 0, part, cut) do
      if is_tuple(note) do
        raise(ArgumentError, "swing cannot hold a loop; swing the music the loop returns")
      end

      case fun.(written) do
        swung when is_number(swung) ->
          {beat + swung, part, note}

        other ->
          other = inspect(other)
          raise ArgumentError, "swing's function returns a beat, not #{other}"
      end
    end
  end

  defp flatten(%Feel{music: music} = feel, beat, part, cut) do
    for {written, part, step} <- flatten(music, 0, part, cut) do
      if is_tuple(step) do
        raise(ArgumentError, "feel cannot hold a loop; feel the music the loop returns")
      end

      index = round(written / feel.step)
      on = if abs(written - index * feel.step) < 0.001, do: index
      seed = {part_name(part), written}
      moved = written + table(feel.push, on, 0) + random(feel.loose, seed, :loose)
      {beat + max(moved, 0), part, leaned(step, part, feel, on, seed)}
    end
  end

  defp flatten(%Each{music: music, opts: opts}, beat, part, cut) do
    for {at, part, step} <- flatten(music, beat, part, cut) do
      case step do
        %Note{} = note ->
          given = if is_list(opts), do: opts, else: opts.(at - beat)

          if not (is_list(given) and Keyword.keyword?(given)) do
            given = inspect(given)
            raise ArgumentError, "each's function returns a list of options, not #{given}"
          end

          note = each_opts(note, given)
          if is_struct(part, Part), do: check_note!(part, note)
          {at, part, note}

        _ ->
          {at, part, step}
      end
    end
  end

  defp table(nil, _on, none), do: none
  defp table(_table, nil, none), do: none
  defp table(table, on, _none), do: Enum.at(table, rem(on, length(table)))

  defp random(nil, _seed, _which), do: 0

  defp random(amount, seed, which) do
    state = :rand.seed_s(:exsss, :erlang.phash2({seed, which}) + 1)
    {draw, _state} = :rand.uniform_s(state)
    (draw * 2 - 1) * amount
  end

  defp part_name(%Part{name: name}), do: name
  defp part_name(_part), do: nil

  defp leaned(%Note{opts: opts} = note, part, %Feel{lean: lean, touch: touch}, on, seed)
       when lean != nil or touch != nil do
    by = table(lean, on, 1) * (1 + random(touch, seed, :touch))

    if by == 1 do
      note
    else
      vel = Keyword.get(opts, :vel) || part_vel(part)

      if vel == nil do
        name = part_name(part)
        written = written(note)

        raise ArgumentError,
              "part #{name}: feel changes a vel, and #{written} has none, nor its part's defaults"
      end

      %{note | opts: Keyword.put(opts, :vel, min(max(vel * by, 0), 1))}
    end
  end

  defp leaned(step, _part, _feel, _on, _seed), do: step

  defp part_vel(%Part{defaults: defaults}), do: Keyword.get(defaults, :vel)
  defp part_vel(_part), do: nil

  # Each part once, in the order it first plays, refusing a name played with other options
  # elsewhere.
  defp parts(played) do
    played
    |> List.flatten()
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
    |> Enum.reduce([], fn part, parts ->
      case Enum.find(parts, &(&1.name == part.name)) do
        nil ->
          [part | parts]

        found ->
          if options(found) == options(part), do: parts, else: refuse_options(part)
      end
    end)
    |> Enum.reverse()
  end

  defp options(part), do: Map.take(part, @part_options)

  defp refuse_options(part) do
    name = part.name

    raise ArgumentError,
          "part #{name} plays with other options in another place; give one of them another name"
  end

  defp part_names(%Part{name: name, music: music}), do: [name | part_names(music)]
  defp part_names(%Seq{items: items}), do: Enum.flat_map(items, &part_names/1)
  defp part_names(%Together{items: items}), do: Enum.flat_map(items, &part_names/1)
  defp part_names(%At{entries: entries}), do: Enum.flat_map(entries, &part_names(elem(&1, 1)))
  defp part_names(%Repeat{music: music}), do: part_names(music)
  defp part_names(%Swing{music: music}), do: part_names(music)
  defp part_names(%Each{music: music}), do: part_names(music)
  defp part_names(%Feel{music: music}), do: part_names(music)
  defp part_names(_music), do: []

  # The notes of the music that no part inside it plays.
  defp own_notes(%Note{} = note), do: [note]
  defp own_notes(%Part{}), do: []
  defp own_notes(%Seq{items: items}), do: Enum.flat_map(items, &own_notes/1)
  defp own_notes(%Together{items: items}), do: Enum.flat_map(items, &own_notes/1)
  defp own_notes(%At{entries: entries}), do: Enum.flat_map(entries, &own_notes(elem(&1, 1)))
  defp own_notes(%Repeat{music: music}), do: own_notes(music)
  defp own_notes(%Swing{music: music}), do: own_notes(music)

  defp own_notes(%Each{music: music, opts: opts}) when is_list(opts) do
    Enum.map(own_notes(music), &each_opts(&1, opts))
  end

  defp own_notes(%Each{music: music}), do: own_notes(music)
  defp own_notes(%Feel{music: music}), do: own_notes(music)
  defp own_notes(_music), do: []

  defp check_note!(%Part{name: name, synth: synth, defaults: defaults}, note) do
    {changes, opts} = Keyword.pop(note.opts, :changes, [])

    result =
      with :ok <- Pass.check_play(synth, defaults, note.pitch, opts),
           :ok <- check_values(synth, opts) do
        Enum.find_value(changes, :ok, fn {_beat, change} ->
          try do
            Pass.check_change(synth, change)

            case check_values(synth, change) do
              :ok -> nil
              error -> error
            end
          rescue
            error in ArgumentError -> {:error, Exception.message(error)}
          end
        end)
      end

    case result do
      :ok ->
        :ok

      {:error, message} ->
        written = written(note)
        raise ArgumentError, "part #{name}: #{message}, in #{written}"
    end
  end

  defp map_notes(music, fun), do: map_notes(music, fun, &map_notes/2)

  defp map_notes(%Note{} = note, fun, _walk), do: fun.(note)

  defp map_notes(%Seq{items: items} = seq, fun, walk) do
    %{seq | items: Enum.map(items, &walk.(&1, fun))}
  end

  defp map_notes(%Together{items: items} = together, fun, walk) do
    %{together | items: Enum.map(items, &walk.(&1, fun))}
  end

  defp map_notes(%At{entries: entries} = at, fun, walk) do
    %{at | entries: Enum.map(entries, fn {beat, music} -> {beat, walk.(music, fun)} end)}
  end

  defp map_notes(%Repeat{music: music} = repeat, fun, walk) do
    %{repeat | music: walk.(music, fun)}
  end

  defp map_notes(%Swing{music: music} = swing, fun, walk), do: %{swing | music: walk.(music, fun)}
  defp map_notes(%Each{music: music} = each, fun, walk), do: %{each | music: walk.(music, fun)}
  defp map_notes(%Feel{music: music} = feel, fun, walk), do: %{feel | music: walk.(music, fun)}
  defp map_notes(%Part{music: music} = part, fun, walk), do: %{part | music: walk.(music, fun)}

  defp map_notes(%MIDI{} = midi, fun, _walk) do
    %Note{pitch: pitch} = fun.(%Note{pitch: midi.note, beats: midi.beats})
    %{midi | note: pitch}
  end

  defp map_notes(%Loop{fun: loop_fun} = loop, fun, walk) do
    %{loop | fun: fn pass, inputs -> pass |> loop_fun.(inputs) |> returned() |> walk.(fun) end}
  end

  defp map_notes(music, _fun, _walk), do: music

  defp written(%Note{pitch: :own_note, beats: beats, opts: opts}) do
    "a hit of #{beats} beats#{written_opts(opts)}"
  end

  defp written(%Note{pitch: pitch, beats: beats, opts: opts}) do
    pitch = inspect(pitch)
    "note(#{pitch}, #{beats}#{written_opts(opts)})"
  end

  defp written(%Sample{ref: ref, beats: beats, opts: opts}) do
    ref = inspect(ref)
    "sample(#{ref}, #{beats}#{written_opts(opts)})"
  end

  defp written(%MIDI{note: note, beats: beats, opts: opts}) do
    "midi(#{note}, #{beats}#{written_opts(opts)})"
  end

  defp written(%Message{kind: kind, args: args}) do
    args = Enum.map_join(args, ", ", &inspect/1)
    "#{kind}(#{args})"
  end

  defp written_opts([]), do: ""

  defp written_opts(opts) do
    opts = opts |> inspect() |> String.slice(1..-2//1)
    ", #{opts}"
  end

  defp item(%struct{} = music)
       when struct in [
              Note,
              Rest,
              Seq,
              Together,
              Repeat,
              At,
              Swing,
              Each,
              Feel,
              Part,
              Loop,
              Sample,
              MIDI,
              Message,
              Change,
              TempoChange
            ],
       do: music

  defp item({:r, beats}), do: rest(beats)
  defp item({name, beats}) when is_atom(name) or is_number(name), do: note(name, beats)
  defp item(items) when is_list(items), do: seq(items)

  defp item(other) do
    other = inspect(other)

    raise ArgumentError,
          "music is a note, a rest, seq, together, repeat, at, swing, steps, loop, part, sample, midi, midi_cc, osc, set, change or tempo, not #{other}"
  end

  defp check_beats(_name, beats) when is_number(beats) and beats >= 0, do: :ok

  defp check_beats(name, beats) do
    beats = inspect(beats)
    raise ArgumentError, "#{name} takes a length in beats from 0 up, not #{beats}"
  end
end
