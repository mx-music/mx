defmodule Mix.Tasks.Mx.Measure do
  @shortdoc "Measures recordings of notes and hits, and compares a synth with them"

  @moduledoc """
  Measures recordings of single notes, plucked or struck, and prints the median fade time and level of their harmonics in each frequency band.

      mix mx.measure Guitar.mf.sulA.A2B2.aif:A2 Guitar.mf.sulE.E2B2.aif:E2
      mix mx.measure Guitar.mf.sulA.A2B2.aif:A2 --synth guitar --vel 0.6

  Each file is followed by a colon and the note it starts on, as a name such as A2 or Bb3, or a MIDI number.
  A file holds one note or several, one after another a semitone apart, each starting from silence, in WAV or AIFF, mono or stereo, at any sample rate.
  It prints the notes it found in each file with their pitch and how far their harmonics are stretched sharp, then for each band the seconds a harmonic takes to fade 60 dB and its level in dB against the fundamental of the lowest note.
  `--synth` renders one of mx's synths offline at each note found, at `--vel` (0.6 unless given), and prints its figures beside the recordings', with the difference.
  `--option` gives the synth another option as a name and a number, such as `--option up=1`, and may be given more than once.

      mix mx.measure --held Flute.vib.mf.B3B4.aiff:B3 --synth flute
      mix mx.measure --hits Cowbell1_Hit_v1_rr1_Sum.wav Marimba.C4.wav:C4

  `--held` measures held notes, bowed, blown or played on an organ, as `Mx.Measure.Held` describes.
  `--drone` with `--held` measures each file as one note held from its first sample to its last, for a drone plucked again and again, which would otherwise read as a note at each pluck.
  It prints each note's pitch, attack and vibrato, then their median attack and vibrato, and for each band the level of the harmonics and of the noise between them, in dB against the fundamental of the lowest note.
  `--hits` measures hits, as `Mx.Measure.Hits` describes, and a file with no pitch needs no note after its name.
  It prints the strongest peaks of each hit as ratios to the lowest, then for each band the seconds it takes to fade 60 dB and its level as the hit starts, against the loudest band.
  `--partials` with a count, such as `--partials 12`, also prints under each hit up to that many of its strongest partials, lowest first: the frequency in Hz, the ratio to the lowest, the level against the loudest, and the seconds it takes to fade 60 dB.

      mix mx.measure --hits Agogo_Low_v1_rr1_Mid.wav --partials 12 --synth low_agogo

  `--hits` then prints each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment, against the loudest band then, as medians over the hits; a moment past a hit's end prints as -, and a level more than 40 dB down as -40.
  `--compare` with a file name, with `--hits` and `--synth`, writes a WAV file of up to three recorded hits whose bands are nearest the median, then the synth's hit three times, each 0.6 seconds at the same peak, for listening or for `mix mx.spectrogram`.

      mix mx.measure --hits "pandeiro A.wav" --synth pandeiro_thumb --compare thumb.wav
  With `--synth`, a held note renders for as long as the recordings hold it, and a hit renders once at each note given, with only the options the synth takes.

      mix mx.measure --strokes "cuica (2).wav"
      mix mx.measure --strokes "cuica (2).wav" --tracks 17,19 --ignore 8500-9100

  `--strokes` measures an instrument played in strokes that run into one another, as `Mx.Measure.Strokes` describes, and a file needs no note after its name.
  It prints each stroke with its number, the second it starts at, its length in ms, the note it settles at, the cents it starts from that note, and its level in dB under the loudest.
  `--tracks` with the numbers of strokes of one file prints each one's tracks instead: its note, the semitones it starts under it, then its pitch in cents at every step of 8 ms, and a row for each step of the levels of its 16 harmonics and of its noise, in dB under its loudest step, with -127 for silence.
  `--alone` with `--tracks` carries on past each stroke into the ring it leaves, for a stroke played by itself.
  `--ignore` with `--tracks` and two frequencies, such as `--ignore 8500-9100`, leaves out the harmonics between them, for a steady tone that is not the instrument's.
  """

  use Mix.Task

  alias Mx.{Audio, Measure, Notes, Signal, Synths}
  alias Mx.Engine.Mxs
  alias Mx.Measure.{Held, Hits, Strokes}

  @example "Guitar.mf.sulA.A2B2.aif:A2"
  @moments "levels in dB at 0, 50, 100 and 200 ms after the loudest moment, against the loudest band then"
  @compared 0.6
  @gap 0.25

  @impl true
  def run(args) when is_list(args) do
    Mix.Task.run("app.config")

    strict = [
      synth: :string,
      vel: :float,
      held: :boolean,
      drone: :boolean,
      hits: :boolean,
      partials: :string,
      option: :keep,
      compare: :string,
      strokes: :boolean,
      tracks: :string,
      alone: :boolean,
      ignore: :string
    ]

    {opts, files} = OptionParser.parse!(args, strict: strict)
    synth = opts[:synth] && synth!(opts[:synth])
    compare = compare!(opts, synth)

    given =
      [vel: Keyword.get(opts, :vel, 0.6)] ++ options!(synth, Keyword.get_values(opts, :option))

    count = count!(opts)

    cond do
      opts[:held] && opts[:hits] -> Mix.raise("give --held or --hits, not both")
      opts[:strokes] -> strokes(files, opts)
      opts[:tracks] || opts[:alone] || opts[:ignore] -> Mix.raise("--tracks needs --strokes")
      opts[:drone] && !opts[:held] -> Mix.raise("--drone needs --held")
      opts[:held] -> held(files, synth, given, opts[:drone] || false)
      opts[:hits] -> hits(files, synth, given, count, compare)
      true -> plucked(files, synth, given)
    end
  end

  defp plucked(files, synth, given) do
    notes =
      files
      |> Enum.map(&parse!/1)
      |> Task.async_stream(fn {path, note} -> {path, Measure.file(path, note)} end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, {path, result}} -> print_file(path, result) end)

    IO.puts("")

    if synth do
      print_beside(Measure.bands(notes), Measure.bands(render(synth, given, notes)), synth, given)
    else
      print_bands(Measure.bands(notes))
    end
  end

  defp held(files, synth, given, drone) do
    measure = if drone, do: &Held.drone/2, else: &Held.file/2

    notes =
      files
      |> Enum.map(&parse!/1)
      |> Task.async_stream(fn {path, note} -> {path, measure.(path, note)} end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, {path, result}} -> print_held_file(path, result) end)

    IO.puts("")
    recorded = Held.summary(notes)

    if synth do
      rendered = Held.summary(render_held(synth, given, notes))
      print_held_beside(recorded, rendered, synth, given)
    else
      print_held(recorded)
    end
  end

  defp hits(files, synth, given, count, compare) do
    measured =
      files
      |> Enum.map(&parse_hit!/1)
      |> Task.async_stream(
        fn {path, note} -> {path, note, Hits.file(path, note, partials: count)} end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {path, note, result}} ->
        {path, note, print_hits_file(path, result)}
      end)

    found = Enum.flat_map(measured, &elem(&1, 2))
    recorded = Hits.summary(found)

    if synth do
      notes = measured |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
      rendered = render_hits(synth, given, notes, count)
      if count, do: print_hits(heading(synth, given), rendered)
      IO.puts("")
      print_beside(recorded, Hits.summary(rendered), synth, given)
      IO.puts("")
      print_moments_beside(Hits.moments(found), Hits.moments(rendered), synth, given)
      if compare, do: compare(compare, measured, recorded, synth, given)
    else
      IO.puts("")
      print_bands(recorded)
      IO.puts("")
      print_moments(Hits.moments(found))
    end
  end

  defp strokes(files, opts) do
    case {opts[:tracks], files} do
      {nil, files} when files != [] ->
        Enum.each(files, &print_strokes(&1, recording!(&1)))

      {tracks, [path]} ->
        given = [alone: opts[:alone] || false, ignore: ignore!(opts[:ignore])]
        recording = recording!(path)
        for index <- indices!(tracks, recording), do: print_tracks(path, recording, index, given)

      _other ->
        Mix.raise("--strokes takes the recordings to measure, and only one with --tracks")
    end
  end

  defp recording!(path) do
    case Strokes.file(path) do
      {:ok, recording} -> recording
      {:error, message} -> Mix.raise(message)
    end
  end

  defp indices!(text, %{strokes: strokes}) do
    last = length(strokes) - 1

    for number <- String.split(text, ",") do
      case Integer.parse(number) do
        {index, ""} when index in 0..last//1 -> index
        _other -> Mix.raise("--tracks takes strokes from 0 to #{last}, such as --tracks 0,3")
      end
    end
  end

  defp ignore!(nil), do: nil

  defp ignore!(text) do
    with [low, high] <- String.split(text, "-"),
         {low, ""} <- Float.parse(low),
         {high, ""} <- Float.parse(high) do
      {low, high}
    else
      _other -> Mix.raise("--ignore takes two frequencies in Hz, such as --ignore 8500-9100")
    end
  end

  defp print_strokes(path, %{strokes: strokes}) do
    count = length(strokes)
    unit = if count == 1, do: "stroke", else: "strokes"
    name = Path.basename(path)
    IO.puts("#{name}: #{count} #{unit}")
    IO.puts("stroke   start     ms    note  starts   level")

    for {stroke, index} <- Enum.with_index(strokes) do
      columns = [
        {"#{index}", 6},
        {:erlang.float_to_binary(stroke.from, decimals: 2), 8},
        {"#{round((stroke.to - stroke.from) * 1000)}", 7},
        {:erlang.float_to_binary(stroke.note, decimals: 2), 8},
        {signed(round(stroke.start), 0), 8},
        {signed(stroke.level, 1), 8}
      ]

      IO.puts(Enum.map_join(columns, fn {text, width} -> String.pad_leading(text, width) end))
    end
  end

  defp print_tracks(path, recording, index, given) do
    name = Path.basename(path)

    case Strokes.tracks(recording, index, given) do
      nil ->
        Mix.raise("stroke #{index} of #{name} has no pitch")

      %{note: note, scoop: scoop, body: body, cents: cents, levels: levels} ->
        note = :erlang.float_to_binary(note, decimals: 2)
        scoop = :erlang.float_to_binary(scoop, decimals: 2)
        steps = length(cents)
        ms = round(Strokes.step() * 1000)
        ring = if body < steps, do: ", the first #{body} the stroke and the rest its ring"

        IO.puts(
          "stroke #{index} of #{name}: note #{note}, scoop #{scoop}, #{steps} steps of #{ms} ms#{ring}"
        )

        IO.puts("cents: " <> Enum.join(cents, ", "))
        IO.puts("levels:")
        for row <- levels, do: IO.puts("[" <> Enum.join(row, ", ") <> "],")
    end
  end

  defp print_moments(moments) do
    IO.puts(@moments)
    times = Enum.map_join(Hits.moment_times(), &String.pad_leading("#{&1}", 5))
    IO.puts(String.pad_trailing("band", 14) <> times)
    for band <- moments, heard?(band.levels), do: IO.puts(label(band) <> levels(band.levels))
  end

  defp print_moments_beside(recorded, rendered, synth, given) do
    rendered = Map.new(rendered, &{&1.band, &1.levels})
    heading = String.pad_trailing(heading(synth, given), 21) <> " "
    IO.puts(@moments)

    IO.puts(
      String.pad_trailing("band", 14) <> "recordings            " <> heading <> "difference"
    )

    for band <- recorded, heard?(band.levels ++ Map.get(rendered, band.band, [])) do
      case rendered[band.band] do
        nil ->
          IO.puts(label(band) <> levels(band.levels))

        other ->
          differences = Enum.zip_with(other, band.levels, &minus/2)
          groups = levels(band.levels) <> "  " <> levels(other) <> "  " <> levels(differences)
          IO.puts(label(band) <> groups)
      end
    end
  end

  # A band that stays 40 dB or more below the loudest at every moment is left out.
  defp heard?(levels), do: Enum.any?(levels, &(&1 && &1 > -40))

  defp levels(levels), do: Enum.map_join(levels, &String.pad_leading(moment(&1), 5))

  defp moment(nil), do: "-"
  defp moment(level), do: signed(round(level), 0)

  # Up to three recorded hits whose bands are nearest the median, then the synth's hit three
  # times, at one peak.
  defp compare(out, measured, recorded, synth, given) do
    picked =
      measured
      |> Enum.flat_map(fn {path, note, hits} ->
        ends = hits |> Enum.drop(1) |> Enum.map(& &1.start) |> Enum.concat([nil])
        for {hit, to} <- Enum.zip(hits, ends), do: {path, note, hit, to}
      end)
      |> Enum.sort_by(fn {_path, _note, hit, _to} -> distance(hit, recorded) end)
      |> Enum.take(3)

    [{_path, note, _hit, _to} | _] = picked
    opts = synth_opts(synth, [note: note] ++ given)
    rendered = in_tmp_dir(&Mxs.render_note(synth, opts, @compared, &1, []))
    parts = Enum.map(picked, &recorded_hit/1) ++ List.duplicate(rendered, 3)
    Audio.write(out, Enum.flat_map(parts, &compared/1), Mxs.render_rate())

    names =
      Enum.map(picked, fn {path, _note, hit, _to} ->
        "#{Path.basename(path)} at #{:erlang.float_to_binary(hit.start, decimals: 2)} s"
      end)

    IO.puts("")
    IO.puts("wrote #{out}: #{listed(names)}, then #{synth} three times")
  end

  defp distance(hit, recorded) do
    levels = Map.new(hit.bands, &{&1.band, &1.level})

    Enum.sum(
      for %{band: band, level: level} <- recorded, do: abs(Map.get(levels, band, -60) - level)
    )
  end

  # The hit from 5 ms before it starts, up to the next hit, high-passed at 30 Hz and at the rate
  # notes render at.
  defp recorded_hit({path, _note, hit, to}) do
    {:ok, %{rate: rate, samples: samples}} = Audio.read(path)
    from = max(round((hit.start - 0.005) * rate), 0)
    count = round(@compared * rate)
    count = if to, do: min(count, round(to * rate) - from), else: count
    margin = round(0.05 * rate)
    before = min(margin, from)

    samples
    |> Enum.slice(from - before, count + before + margin)
    |> Signal.high_pass(rate, 30)
    |> Enum.slice(before, count)
    |> resample(rate, Mxs.render_rate())
  end

  defp resample(samples, rate, rate), do: samples

  defp resample(samples, from, to) do
    sound = List.to_tuple(samples)
    last = tuple_size(sound) - 1

    for index <- 0..(floor(last * to / from) - 1)//1 do
      position = index * from / to
      below = floor(position)
      fraction = position - below
      elem(sound, below) * (1 - fraction) + elem(sound, min(below + 1, last)) * fraction
    end
  end

  defp compared(samples) do
    length = round(@compared * Mxs.render_rate())
    padded = Enum.take(samples ++ List.duplicate(0.0, length), length)
    peak = padded |> Enum.map(&abs/1) |> Enum.max()
    fade = round(0.01 * Mxs.render_rate())

    # The last 10 ms fade out, so a hit still ringing at the cut ends without a click.
    scaled =
      padded
      |> Enum.with_index(fn sample, index ->
        sample / max(peak, 1.0e-9) * 0.5 * min(1, (length - 1 - index) / fade)
      end)

    scaled ++ List.duplicate(0.0, round(@gap * Mxs.render_rate()))
  end

  defp listed([one]), do: one
  defp listed(names), do: Enum.join(Enum.drop(names, -1), ", ") <> " and " <> List.last(names)

  defp compare!(opts, synth) do
    case {opts[:compare], opts[:hits], synth} do
      {nil, _hits, _synth} -> nil
      {compare, true, synth} when synth != nil -> compare
      _other -> Mix.raise("--compare needs --hits and --synth")
    end
  end

  defp count!(opts) do
    case {opts[:partials], opts[:hits]} do
      {nil, _hits} -> nil
      {_count, true} -> parse_count!(opts[:partials])
      {_count, _hits} -> Mix.raise("--partials needs --hits")
    end
  end

  defp parse_count!(text) do
    case Integer.parse(text) do
      {count, ""} when count >= 1 -> count
      _other -> Mix.raise("--partials takes a count from 1 up, such as --partials 12")
    end
  end

  defp parse!(arg) do
    case Regex.run(~r/^(.+):([^:]+)$/, arg) do
      [_, path, note] -> {path, note!(note)}
      nil -> Mix.raise("give each file with the note it starts on, such as #{@example}")
    end
  end

  defp parse_hit!(arg) do
    case Regex.run(~r/^(.+):([^:]+)$/, arg) do
      [_, path, note] -> {path, note!(note)}
      nil -> {arg, nil}
    end
  end

  defp note!(text) do
    Notes.from_text(text)
  rescue
    ArgumentError -> Mix.raise("unknown note #{text}")
  end

  defp synth!(name) do
    Enum.find(Synths.synths(), &(&1 == name)) ||
      Mix.raise("unknown synth #{name}")
  end

  defp print_file(_path, {:error, message}), do: Mix.raise(message)

  defp print_file(path, {:ok, notes}) do
    name = Path.basename(path)
    count = length(notes)
    unit = if count == 1, do: "note", else: "notes"
    names = Enum.map_join(notes, " ", &Measure.name(&1.note))
    IO.puts("#{name}: #{count} #{unit}, #{names}")

    for note <- notes do
      pitch = :erlang.float_to_binary(note.pitch, decimals: 1)
      stretch = :erlang.float_to_binary(note.stretch, scientific: 1)
      label = Measure.name(note.note)
      IO.puts("  #{label} at #{pitch} Hz, stretched #{stretch}")
    end

    notes
  end

  defp print_held_file(_path, {:error, message}), do: Mix.raise(message)

  defp print_held_file(path, {:ok, notes}) do
    name = Path.basename(path)
    count = length(notes)
    unit = if count == 1, do: "note", else: "notes"
    names = Enum.map_join(notes, " ", &Measure.name(&1.note))
    IO.puts("#{name}: #{count} #{unit}, #{names}")

    for note <- notes do
      pitch = :erlang.float_to_binary(note.pitch, decimals: 1)
      attack = seconds(note.attack)
      vibrato = if note.vibrato, do: "vibrato " <> vibrato(note.vibrato), else: "no vibrato"
      label = Measure.name(note.note)
      IO.puts("  #{label} at #{pitch} Hz, attack #{attack}, #{vibrato}")
    end

    notes
  end

  defp print_hits_file(_path, {:error, message}), do: Mix.raise(message)

  defp print_hits_file(path, {:ok, hits}), do: print_hits(Path.basename(path), hits)

  defp print_hits(name, hits) do
    count = length(hits)
    unit = if count == 1, do: "hit", else: "hits"
    IO.puts("#{name}: #{count} #{unit}")

    for {hit, number} <- Enum.with_index(hits, 1) do
      peaks = Enum.map_join(hit.peaks, ", ", &:erlang.float_to_binary(&1, decimals: 2))
      IO.puts("  hit #{number}: peaks at #{peaks}")
      Enum.each(hit.partials, &IO.puts(partial(&1)))
    end

    hits
  end

  defp partial(%{hz: hz, ratio: ratio, level: level, ring: ring}) do
    hz = :erlang.float_to_binary(hz, decimals: 1) <> " Hz"
    ratio = :erlang.float_to_binary(ratio, decimals: 2)
    ring = if ring, do: seconds(ring), else: "-"

    "    " <>
      String.pad_leading(hz, 10) <>
      String.pad_leading(ratio, 7) <>
      String.pad_leading(decibels(level), 10) <> String.pad_leading(ring, 8)
  end

  defp render_held(synth, given, notes) do
    in_tmp_dir(fn dir ->
      notes
      |> Task.async_stream(
        fn note ->
          opts = synth_opts(synth, [note: note.note, sustain: note.held] ++ given)
          sound = Mxs.render_note(synth, opts, note.held + 2, dir, [])
          Held.note(sound, Mxs.render_rate(), note.note)
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
    end)
  end

  defp render_hits(synth, given, notes, count) do
    in_tmp_dir(fn dir ->
      notes
      |> Task.async_stream(
        fn note ->
          opts = synth_opts(synth, [note: note] ++ given)
          sound = Mxs.render_note(synth, opts, 4, dir, [])
          Hits.hit(sound, Mxs.render_rate(), note, partials: count)
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, hit} -> List.wrap(hit) end)
    end)
  end

  defp synth_opts(synth, opts) do
    for {key, value} <- opts, value != nil, Synths.option?(synth, key), do: {key, value}
  end

  defp in_tmp_dir(fun) do
    dir = Path.join(System.tmp_dir!(), "mx-measure-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end

  defp render(synth, given, notes) do
    dir = Path.join(System.tmp_dir!(), "mx-measure-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      notes
      |> Enum.map(& &1.note)
      |> Enum.uniq()
      |> Task.async_stream(
        fn note ->
          sound = Mxs.render_note(synth, [note: note] ++ given, 4.4, dir, [])
          Measure.note(sound, Mxs.render_rate(), note)
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
    after
      File.rm_rf!(dir)
    end
  end

  defp print_bands(bands) do
    IO.puts(String.pad_trailing("band", 14) <> "      fade     level")

    for band <- bands do
      IO.puts(String.trim_trailing(label(band) <> figures(band)))
    end
  end

  defp print_held(summary) do
    vibrato = if summary.vibrato, do: vibrato(summary.vibrato), else: "none"
    IO.puts(String.pad_trailing("attack", 14) <> seconds(summary.attack))
    IO.puts(String.pad_trailing("vibrato", 14) <> vibrato)
    IO.puts("")
    IO.puts(String.pad_trailing("band", 14) <> "     level     noise")

    for band <- summary.bands do
      IO.puts(label(band) <> held_figures(band))
    end
  end

  defp print_held_beside(recorded, rendered, synth, given) do
    heading = heading(synth, given)

    IO.puts(
      String.pad_trailing("", 14) <> column("recordings") <> column(heading) <> "difference"
    )

    attack = signed(round((rendered.attack / recorded.attack - 1) * 100), 0) <> "%"
    attacks = column(seconds(recorded.attack)) <> column(seconds(rendered.attack)) <> attack
    IO.puts(String.pad_trailing("attack", 14) <> attacks)
    vibratos = column(vibrato(recorded.vibrato)) <> column(vibrato(rendered.vibrato))

    IO.puts(
      String.pad_trailing("vibrato", 14) <> vibratos <> vibrato_difference(recorded, rendered)
    )

    IO.puts("")
    figures = "     level     noise"
    IO.puts(String.pad_trailing("band", 14) <> figures <> figures <> figures)
    rendered = Map.new(rendered.bands, &{&1.band, &1})

    for band <- recorded.bands do
      case rendered[band.band] do
        nil ->
          IO.puts(label(band) <> held_figures(band))

        other ->
          differences =
            held_figures(%{
              level: minus(other.level, band.level),
              noise: minus(other.noise, band.noise)
            })

          IO.puts(label(band) <> held_figures(band) <> held_figures(other) <> differences)
      end
    end
  end

  defp heading(synth, given) do
    taken = for {name, value} <- given, Synths.option?(synth, name), do: "#{name} #{value}"
    if taken == [], do: "#{synth}", else: "#{synth} at #{Enum.join(taken, ", ")}"
  end

  defp options!(_synth, []), do: []
  defp options!(nil, _options), do: Mix.raise("--option needs --synth")

  defp options!(synth, options) do
    for option <- options do
      with [name, text] <- String.split(option, "=", parts: 2),
           {value, ""} <- Float.parse(text) do
        value = if value == trunc(value), do: trunc(value), else: value
        {option!(synth, name), value}
      else
        _other -> Mix.raise("give --option as a name and a number, such as --option up=1")
      end
    end
  end

  # Every option a synth takes is already an atom, so a name that is not one is no option.
  defp option!(synth, name) do
    option =
      try do
        String.to_existing_atom(name)
      rescue
        ArgumentError -> nil
      end

    if option && Synths.option?(synth, option) do
      option
    else
      Mix.raise("#{synth} has no option #{name}")
    end
  end

  defp column(text), do: String.pad_trailing(text, 19) <> " "

  defp seconds(value), do: :erlang.float_to_binary(value, decimals: 2) <> " s"

  defp vibrato(nil), do: "none"

  defp vibrato(%{rate: rate, depth: depth}) do
    rate = :erlang.float_to_binary(rate, decimals: 1)
    cents = round(depth)
    "#{rate} Hz, #{cents} cents"
  end

  defp vibrato_difference(%{vibrato: %{} = recorded}, %{vibrato: %{} = rendered}) do
    rate = signed(rendered.rate - recorded.rate, 1)
    cents = signed(round(rendered.depth - recorded.depth), 0)
    "#{rate} Hz, #{cents} cents"
  end

  defp vibrato_difference(_recorded, _rendered), do: "-"

  defp held_figures(%{level: level, noise: noise}) do
    String.pad_leading(decibels(level), 10) <> String.pad_leading(decibels(noise), 10)
  end

  defp decibels(nil), do: "-"
  defp decibels(value), do: signed(value, 1) <> " dB"

  defp minus(nil, _other), do: nil
  defp minus(_value, nil), do: nil
  defp minus(value, other), do: value - other

  defp print_beside(recorded, rendered, synth, given) do
    rendered = Map.new(rendered, &{&1.band, &1})
    heading = column(heading(synth, given))
    IO.puts(String.pad_trailing("band", 14) <> "recordings          " <> heading <> "difference")

    for band <- recorded do
      case rendered[band.band] do
        nil ->
          IO.puts(String.trim_trailing(label(band) <> figures(band)))

        other ->
          IO.puts(label(band) <> figures(band) <> figures(other) <> difference(band, other))
      end
    end
  end

  defp label(%{band: {low, high}}), do: String.pad_trailing("#{low}-#{high} Hz", 14)

  defp figures(%{fade: fade, level: level}) do
    fade = if fade, do: :erlang.float_to_binary(fade, decimals: 2) <> " s", else: "-"
    level = signed(level, 1) <> " dB"
    String.pad_leading(fade, 8) <> String.pad_leading(level, 10) <> "  "
  end

  defp difference(recorded, rendered) do
    fade =
      if recorded.fade && rendered.fade do
        signed(round((rendered.fade / recorded.fade - 1) * 100), 0) <> "%"
      else
        "-"
      end

    level = signed(rendered.level - recorded.level, 1) <> " dB"
    String.pad_leading(fade, 6) <> String.pad_leading(level, 10)
  end

  defp signed(value, 0), do: if(value >= 0, do: "+#{value}", else: "#{value}")

  defp signed(value, decimals) do
    text = :erlang.float_to_binary(value / 1, decimals: decimals)
    if value >= 0, do: "+" <> text, else: text
  end
end
