defmodule Mix.Tasks.Mx.Measure do
  @shortdoc "Measures recordings of notes and hits, and compares a synth with them"

  @moduledoc """
  Measures recordings of single notes, plucked or struck, and prints the median fade time and level of their harmonics in each frequency band.

      mx measure Guitar.mf.sulA.A2B2.aif:A2 Guitar.mf.sulE.E2B2.aif:E2
      mx measure Guitar.mf.sulA.A2B2.aif:A2 --synth guitar --vel 0.6

  Each file is followed by a colon and the note it starts on, as a name such as A2 or Bb3, or a MIDI number.
  A file holds one note or several, one after another a semitone apart, each starting from silence, in WAV or AIFF, mono or stereo, at any sample rate.
  It prints the notes it found in each file with their pitch and how far their harmonics are stretched sharp, then for each band the seconds a harmonic takes to fade 60 dB and its level in dB against the fundamental of the lowest note.
  `--synth` renders one of mx's synths offline at each note found, at `--vel` (0.6 unless given), and prints its figures beside the recordings', with the difference.
  `--option` gives the synth another option as a name and a number, such as `--option up=1`, and may be given more than once.

      mx measure --held Flute.vib.mf.B3B4.aiff:B3 --synth flute
      mx measure --hits Cowbell1_Hit_v1_rr1_Sum.wav Marimba.C4.wav:C4

  `--held` measures held notes, bowed, blown or played on an organ, as `Mx.Measure.Held` describes.
  `--drone` with `--held` measures each file as one note held from its first sample to its last, for a drone plucked again and again, which would otherwise read as a note at each pluck.
  It prints each note's pitch, attack and vibrato, then their median attack and vibrato, and for each band the level of the harmonics and of the noise between them, in dB against the fundamental of the lowest note.
  `--hits` measures hits, as `Mx.Measure.Hits` describes, and a file with no pitch needs no note after its name.
  A file of several hits named with its first note, such as `Vibraphone.sustain.ff.C3B3.aif:C3`, is a run, split into its notes as `mix mx.fit` splits one, and each hit is named by its note.
  It prints the strongest peaks of each hit as ratios to the lowest, then for each band the seconds it takes to fade 60 dB and its level as the hit starts, against the loudest band.
  `--partials` with a count, such as `--partials 12`, also prints under each hit up to that many of its strongest partials, lowest first: the frequency in Hz, the ratio to the lowest, the level against the loudest, and the seconds it takes to fade 60 dB.
  With `--held`, it prints for each note where it holds from, where it is let go, how fast it falls then and its vibrato, and under it up to that many of its strongest partials: the level at each moment of the attack before it holds, the level it holds at, its slope once let go and how far it swings with the vibrato, as `Mx.Fit.Held` measures them.
  Without `--hits` or `--held`, it prints under each file up to that many of the strongest partials of the note it starts with, as `Mx.Measure.partials/2` measures them, lowest first: the frequency in Hz, the ratio to the pitch, the harmonic or between, the level against the loudest as the note starts, and how it falls, or rises, in dB a second, with the second slope and where it starts when it slows; then each line left out as not the instrument's.

      mx measure keyboard_electronic_098-064-025.wav:E4 --partials 20

      mx measure --hits Agogo_Low_v1_rr1_Mid.wav --partials 12 --synth low_agogo

  `--hits` then prints each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment, against the loudest band then, as medians over the hits; a moment past a hit's end prints as -, and a level more than 40 dB down as -40.
  Under them it prints how bright the hits are over time: the sound above 1, 2, 4 and 8 kHz in dB under the whole sound, from 0 to 20, 20 to 80 and 80 to 200 ms after the hit starts, and the milliseconds after the hit starts at which the sound above 4 kHz is loudest, then that sound's level at 5, 10, 20, 40, 80, 160 and 320 ms after the hit starts, in dB under its loudest, beside the synth's with `--synth`.
  `--compare` with a file name, with `--hits` and `--synth`, writes a WAV file of up to three recorded hits whose bands are nearest the median, then the synth's hit at each of their notes, each 0.6 seconds at the same peak, for listening or for `mx spectrogram`.

      mx measure --hits "pandeiro A.wav" --synth pandeiro_thumb --compare thumb.wav
  With `--synth`, a held note renders for as long as the recordings hold it, and a hit renders once at the note of each hit found, with only the options the synth takes.

      mx measure --strokes "cuica (2).wav"
      mx measure --strokes "cuica (2).wav" --tracks 17,19 --ignore 8500-9100

  `--strokes` measures an instrument played in strokes that run into one another, as `Mx.Measure.Strokes` describes, and a file needs no note after its name.
  It prints each stroke with its number, the second it starts at, its length in ms, the note it settles at, the cents it starts from that note, and its level in dB under the loudest.
  `--tracks` with the numbers of strokes of one file prints each one's tracks instead: its note, the semitones it starts under it, then its pitch in cents at every step of 8 ms, and a row for each step of the levels of its 16 harmonics and of its noise, in dB under its loudest step, with -127 for silence.
  `--alone` with `--tracks` carries on past each stroke into the ring it leaves, for a stroke played by itself.
  `--ignore` with `--tracks` and two frequencies, such as `--ignore 8500-9100`, leaves out the harmonics between them, for a steady tone that is not the instrument's.

      mx measure --known

  `--known` measures notes it makes itself, whose partials are known exactly, in the same way `mx fit --struck` measures a recording, and needs no recordings.
  There are six kinds of note, each at C2, C4 and C7: a partial falling 60 dB over 3 seconds, a partial falling 30 dB in 25 ms, two partials 20 Hz apart that beat, a fundamental rising 40 dB over 40 ms under a partial that starts at once, a partial 30 dB under a burst of white noise 50 ms long, and a short partial at once while the fundamental comes within 20 dB of its peak 30 ms later.
  For each note it prints how far the measured strike is from the true one in ms, and for each partial how far its measured level is from the true one, as the peak over the first 20 ms and on average over the note in dB, and its frequency in cents.
  A figure beyond 2 dB, the limit refit tickets use, is marked, and the last lines say at which pitches each kind is followed within it.
  Read these figures before setting a refit's criteria: no fit can be closer to a recording than the measuring is to the truth.
  """

  use Mix.Task

  alias Mx.{Audio, Measure, Notes, Signal, Synths}
  alias Mx.Engine.Mxs
  alias Mx.Measure.{Held, Hits, Strokes}

  @example "Guitar.mf.sulA.A2B2.aif:A2"
  @moments "levels in dB at 0, 50, 100 and 200 ms after the loudest moment, against the loudest band then"
  @brightness "the sound above each frequency in dB under the whole sound, from 0 to 20, 20 to 80 and 80 to 200 ms after the hit starts"
  @highs "the sound above 4 kHz in dB under its loudest, at 5, 10, 20, 40, 80, 160 and 320 ms after the hit starts"
  @compared 0.6
  @gap 0.25
  @attack_ms [0, 10, 20, 40, 70, 115, 180, 280, 440, 700]

  @impl true
  def run(args) when is_list(args) do
    Mx.Command.config()

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
      ignore: :string,
      known: :boolean
    ]

    {opts, files} = OptionParser.parse!(args, strict: strict)
    synth = opts[:synth] && synth!(opts[:synth])
    compare = compare!(opts, synth)

    given =
      [vel: Keyword.get(opts, :vel, 0.6)] ++ options!(synth, Keyword.get_values(opts, :option))

    count = count!(opts)

    cond do
      opts[:known] ->
        known()

      opts[:held] && opts[:hits] ->
        Mx.Command.fail("give --held or --hits, not both")

      opts[:strokes] ->
        strokes(files, opts)

      opts[:tracks] || opts[:alone] || opts[:ignore] ->
        Mx.Command.fail("--tracks needs --strokes")

      opts[:drone] && !opts[:held] ->
        Mx.Command.fail("--drone needs --held")

      true ->
        measure(files, opts, {synth, given, count, compare})
    end
  end

  defp measure(files, opts, {synth, given, count, compare}) do
    cond do
      opts[:held] && count ->
        held_partials(files, count)

      opts[:held] ->
        held(files, synth, given, opts[:drone] || false)

      opts[:hits] ->
        hits(files, synth, given, count, compare)

      true ->
        plucked(files, synth, given, count)
    end
  end

  defp known do
    measured = Mxs.Native.measure_known()

    for known <- measured do
      name = String.upcase(Measure.name(round(known.note)))
      strike = :erlang.float_to_binary(known.strike, decimals: 1)
      IO.puts("#{name} #{known.kind}: strike #{signed(strike)} ms")
      Enum.each(known.partials, &print_known/1)
    end

    IO.puts("")

    measured
    |> Enum.group_by(& &1.kind)
    |> Enum.sort_by(&kind_order/1)
    |> Enum.each(fn {kind, notes} ->
      {followed, missed} = Enum.split_with(notes, & &1.followed)
      IO.puts("#{kind}: #{followed_line(followed, missed)}")
    end)
  end

  defp kind_order({kind, _}) do
    Enum.find_index(~w(slow short beating building noisy early), &(&1 == kind))
  end

  defp print_known(%{found: false, freq: freq}) do
    freq = Float.round(freq, 1)
    IO.puts("  #{freq} Hz: not found")
  end

  defp print_known(%{
         freq: freq,
         first: first,
         mean: mean,
         cents: cents,
         off: {first_off, mean_off}
       }) do
    first = :erlang.float_to_binary(first, decimals: 1)
    mean = :erlang.float_to_binary(mean, decimals: 1)
    cents = :erlang.float_to_binary(cents, decimals: 1)

    IO.puts(
      "  #{Float.round(freq, 1)} Hz: first 20 ms #{signed(first)} dB#{beyond(first_off)}, " <>
        "average #{mean} dB#{beyond(mean_off)}, #{signed(cents)} cents"
    )
  end

  defp signed("-" <> _ = text), do: text
  defp signed(text), do: "+" <> text

  defp beyond(true), do: " (beyond 2 dB)"
  defp beyond(false), do: ""

  defp followed_line(followed, missed) do
    names = fn notes ->
      notes |> Enum.map(&Measure.name(round(&1.note))) |> Enum.map(&String.upcase/1)
    end

    case {names.(followed), names.(missed)} do
      {[], missed} ->
        "not followed within 2 dB at #{Enum.join(missed, ", ")}"

      {followed, []} ->
        "followed within 2 dB at #{Enum.join(followed, ", ")}"

      {followed, missed} ->
        "followed within 2 dB at #{Enum.join(followed, ", ")}, not at #{Enum.join(missed, ", ")}"
    end
  end

  defp plucked(files, synth, given, count) do
    notes =
      files
      |> Enum.map(&parse!/1)
      |> Task.async_stream(
        fn {path, note} ->
          {path, Measure.file(path, note), count && Measure.partials(path, note)}
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, {path, result, partials}} ->
        notes = print_file(path, result)
        if partials, do: print_partials(partials, count)
        notes
      end)

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

  defp held_partials(files, count) do
    for {path, note} <- Enum.map(files, &parse!/1) do
      notes =
        case Held.file(path, note) do
          {:ok, found} -> Enum.map(found, & &1.note)
          {:error, message} -> Mx.Command.fail(message)
        end

      recordings =
        case Mx.Fit.Struck.in_file(path, notes, 127, held: true) do
          {:ok, recordings} -> Enum.sort_by(recordings, & &1.note)
          {:error, message} -> Mx.Command.fail(message)
        end

      name = Path.basename(path)
      IO.puts("#{name}: #{length(recordings)} notes")
      Enum.each(Mx.Fit.Held.measure(recordings), &print_held_partials(&1, count))
    end
  end

  defp print_held_partials(measured, count) do
    label = Measure.name(measured.note)
    pitch = :erlang.float_to_binary(measured.pitch, decimals: 1)
    held = seconds(measured.held)
    release = seconds(measured.release)
    falls = slope(measured.fall)
    {rate, depth} = measured.vibrato

    vibrato =
      if depth > 0 do
        rate = :erlang.float_to_binary(rate, decimals: 1)
        "vibrato #{rate} Hz, #{round(depth)} cents"
      else
        "no vibrato"
      end

    IO.puts(
      "  #{label} at #{pitch} Hz: holds from #{held}, let go at #{release}, then #{falls}; #{vibrato}"
    )

    partials =
      measured.partials
      |> Enum.sort_by(& &1.held, :desc)
      |> Enum.take(count)
      |> Enum.sort_by(& &1.freq)

    for partial <- partials do
      freq = :erlang.float_to_binary(partial.freq, decimals: 1)
      level = :erlang.float_to_binary(partial.held, decimals: 1)

      attack =
        partial.attack
        |> Enum.filter(fn {at, _level} -> round(at * 1000) in @attack_ms end)
        |> Enum.map_join(", ", fn {at, level} ->
          ms = round(at * 1000)
          "#{:erlang.float_to_binary(level, decimals: 1)} at #{ms} ms"
        end)

      falls = slope(partial.release)
      swing = :erlang.float_to_binary(partial.swing, decimals: 1)
      swings = if depth > 0, do: ", swings #{swing} dB with the vibrato", else: ""

      IO.puts(
        "    harmonic #{partial.harmonic}, #{freq} Hz: attack #{attack}; holds at #{level} dB; let go, #{falls}#{swings}"
      )
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
      notes = found |> Enum.map(& &1.note) |> Enum.uniq()
      rendered = render_hits(synth, given, notes, count)
      if count, do: print_hits(heading(synth, given), rendered)
      IO.puts("")
      print_beside(recorded, Hits.summary(rendered), synth, given)
      IO.puts("")
      print_moments_beside(Hits.moments(found), Hits.moments(rendered), synth, given)
      IO.puts("")
      print_brightness_beside(found, rendered, synth, given)
      if compare, do: compare(compare, measured, recorded, synth, given)
    else
      IO.puts("")
      print_bands(recorded)
      IO.puts("")
      print_moments(Hits.moments(found))
      IO.puts("")
      print_brightness(found)
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
        Mx.Command.fail("--strokes takes the recordings to measure, and only one with --tracks")
    end
  end

  defp recording!(path) do
    case Strokes.file(path) do
      {:ok, recording} -> recording
      {:error, message} -> Mx.Command.fail(message)
    end
  end

  defp indices!(text, %{strokes: strokes}) do
    last = length(strokes) - 1

    for number <- String.split(text, ",") do
      case Integer.parse(number) do
        {index, ""} when index in 0..last//1 ->
          index

        _other ->
          Mx.Command.fail("--tracks takes strokes from 0 to #{last}, such as --tracks 0,3")
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
      _other ->
        Mx.Command.fail("--ignore takes two frequencies in Hz, such as --ignore 8500-9100")
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
        Mx.Command.fail("stroke #{index} of #{name} has no pitch")

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

  defp print_brightness(hits) do
    IO.puts(@brightness)
    IO.puts(String.pad_trailing("", 14) <> stretches())
    for row <- Hits.brightness(hits), do: IO.puts(above(row) <> levels(row.levels))
    IO.puts(highs_peak(Hits.highs_peak(hits)))
    print_highs([{"above 4000 Hz", Hits.highs(hits)}])
  end

  defp print_brightness_beside(recorded, rendered, synth, given) do
    theirs = Map.new(Hits.brightness(rendered), &{&1.above, &1.levels})
    heading = String.pad_trailing(heading(synth, given), 16) <> " "
    IO.puts(@brightness)
    IO.puts(String.pad_trailing("", 14) <> "recordings       " <> heading <> "difference")

    for row <- Hits.brightness(recorded) do
      other = Map.get(theirs, row.above, Enum.map(row.levels, fn _level -> nil end))
      differences = Enum.zip_with(other, row.levels, &minus/2)
      groups = levels(row.levels) <> "  " <> levels(other) <> "  " <> levels(differences)
      IO.puts(above(row) <> groups)
    end

    IO.puts("recordings: " <> highs_peak(Hits.highs_peak(recorded)))
    IO.puts(heading(synth, given) <> ": " <> highs_peak(Hits.highs_peak(rendered)))

    print_highs([
      {"recordings", Hits.highs(recorded)},
      {heading(synth, given), Hits.highs(rendered)}
    ])
  end

  defp print_highs(rows) do
    if Enum.any?(rows, fn {_name, highs} -> highs != [] end) do
      IO.puts("")
      IO.puts(@highs)
      width = rows |> Enum.map(fn {name, _highs} -> String.length(name) end) |> Enum.max()

      for {name, highs} <- rows,
          do: IO.puts(String.pad_trailing(name, width + 1) <> levels(highs))
    end
  end

  defp stretches do
    Enum.map_join(Hits.stretches(), fn {from, _to} -> String.pad_leading("#{from}", 5) end)
  end

  defp above(%{above: above}), do: String.pad_trailing("above #{above} Hz", 14)

  defp highs_peak(nil), do: "nothing above 4 kHz to peak"

  defp highs_peak(ms) do
    rounded = round(ms)
    "the sound above 4 kHz is loudest #{rounded} ms after the hit starts"
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

    notes = Enum.map(picked, fn {_path, _note, hit, _to} -> hit.note end)

    rendered =
      in_tmp_dir(fn dir ->
        for note <- Enum.uniq(notes), into: %{} do
          opts = synth_opts(synth, [note: note] ++ given)
          {note, Mxs.render_note(synth, opts, @compared, dir, [])}
        end
      end)

    parts = Enum.map(picked, &recorded_hit/1) ++ Enum.map(notes, &rendered[&1])
    Audio.write(out, Enum.flat_map(parts, &compared/1), Mxs.render_rate())

    names =
      Enum.map(picked, fn {path, _note, hit, _to} ->
        "#{Path.basename(path)} at #{:erlang.float_to_binary(hit.start, decimals: 2)} s"
      end)

    times = if length(Enum.uniq(notes)) > 1, do: "at the same notes", else: "three times"
    IO.puts("")
    IO.puts("wrote #{out}: #{listed(names)}, then #{synth} #{times}")
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
      Enum.with_index(padded, fn sample, index ->
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
      _other -> Mx.Command.fail("--compare needs --hits and --synth")
    end
  end

  defp count!(opts) do
    cond do
      opts[:partials] == nil -> nil
      opts[:strokes] -> Mx.Command.fail("--partials needs --hits, --held or plucked notes")
      true -> parse_count!(opts[:partials])
    end
  end

  defp parse_count!(text) do
    case Integer.parse(text) do
      {count, ""} when count >= 1 -> count
      _other -> Mx.Command.fail("--partials takes a count from 1 up, such as --partials 12")
    end
  end

  defp parse!(arg) do
    case Regex.run(~r/^(.+):([^:]+)$/, arg) do
      [_, path, note] -> {path, note!(note)}
      nil -> Mx.Command.fail("give each file with the note it starts on, such as #{@example}")
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
    ArgumentError -> Mx.Command.fail("unknown note #{text}")
  end

  defp synth!(name) do
    Enum.find(Synths.synths(), &(&1 == name)) ||
      Mx.Command.fail("unknown synth #{name}")
  end

  defp print_file(_path, {:error, message}), do: Mx.Command.fail(message)

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

  defp print_partials({:error, message}, _count), do: Mx.Command.fail(message)

  defp print_partials({:ok, measured}, count) do
    strongest =
      measured.partials
      |> Enum.sort_by(& &1.level, :desc)
      |> Enum.take(count)
      |> Enum.sort_by(& &1.freq)

    Enum.each(strongest, &IO.puts(struck_partial(&1, measured.pitch, "")))

    Enum.each(
      measured.left_out,
      &IO.puts(struck_partial(&1, measured.pitch, "left out, no strike or fall: "))
    )
  end

  defp struck_partial(partial, pitch, label) do
    hz = :erlang.float_to_binary(partial.freq, decimals: 1) <> " Hz"
    ratio = :erlang.float_to_binary(partial.freq / pitch, decimals: 3)
    kind = if partial.harmonic > 0, do: "harmonic #{partial.harmonic}", else: "between"

    "    " <>
      label <>
      String.pad_leading(hz, 10) <>
      String.pad_leading(ratio, 8) <>
      "  " <>
      String.pad_trailing(kind, 12) <>
      String.pad_leading(decibels(partial.level), 8) <> "  " <> falls(partial)
  end

  defp falls(%{fall: nil}), do: "-"

  defp falls(%{fall: fall, knee: nil}), do: slope(fall)

  defp falls(%{fall: fall, knee: knee, then: then}) do
    first = slope(fall)
    second = slope(then)
    knee = seconds(knee)
    "#{first}, then #{second} after #{knee}"
  end

  defp slope(slope) when slope > 0 do
    rate = round(slope)
    "rises #{rate} dB/s"
  end

  defp slope(slope) do
    rate = round(-slope)
    "falls #{rate} dB/s"
  end

  defp print_held_file(_path, {:error, message}), do: Mx.Command.fail(message)

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

  defp print_hits_file(_path, {:error, message}), do: Mx.Command.fail(message)

  defp print_hits_file(path, {:ok, hits}), do: print_hits(Path.basename(path), hits)

  defp print_hits(name, hits) do
    count = length(hits)
    unit = if count == 1, do: "hit", else: "hits"
    IO.puts("#{name}: #{count} #{unit}")

    run? = hits |> Enum.map(& &1.note) |> Enum.uniq() |> length() > 1

    for {hit, number} <- Enum.with_index(hits, 1) do
      peaks = Enum.map_join(hit.peaks, ", ", &:erlang.float_to_binary(&1, decimals: 2))
      label = if run?, do: "hit #{number}, #{Measure.name(hit.note)}", else: "hit #{number}"
      IO.puts("  #{label}: peaks at #{peaks}")
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
  defp options!(nil, _options), do: Mx.Command.fail("--option needs --synth")

  defp options!(synth, options) do
    for option <- options do
      with [name, text] <- String.split(option, "=", parts: 2),
           {value, ""} <- Float.parse(text) do
        value = if value == trunc(value), do: trunc(value), else: value
        {option!(synth, name), value}
      else
        _other -> Mx.Command.fail("give --option as a name and a number, such as --option up=1")
      end
    end
  end

  defp option!(synth, name) do
    if option = Synths.option(synth, name) do
      option
    else
      Mx.Command.fail("#{synth} has no option #{name}")
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
