defmodule Mix.Tasks.Mx.Fit do
  @shortdoc "Fits a synth to recordings of held or struck notes partial by partial, or of held notes by its controls"

  @moduledoc """
  Searches for the values of a synth's controls that bring its held notes closest to recordings of them, as `Mx.Fit` describes.

      mx fit clarinet --vel 0.3 BbClar.pp.D3B3.aiff:D3 BbClar.pp.C4B4.aiff:C4 --vel 1 BbClar.ff.D3B3.aiff:D3 --from 160 --control k_odd=-2:2 --control k_att=0.15:x1.15

  The synth comes first, then each dynamic as `--vel` and the files played at it, each with the note it starts on, as `mx measure` takes them.
  `--control` gives a control the synth takes, its starting value and its step, such as `k_odd=-2:2`; a step written with an x, such as `x1.15`, multiplies and divides instead of adding and subtracting.
  `--from` gives the lowest frequency in Hz of the bands compared, all of them below 4 kHz unless given.
  It prints how many notes it kept at each dynamic and how many it left out, the score it starts from, each change it keeps, and the best values at the end.
  `--drone` measures each file as one note held from its first sample to its last, for a drone plucked again and again, which would otherwise read as a note at each pluck, and leaves out the attack.
  `--check` scores the starting values instead of searching, and needs no control; it prints each dynamic's attack difference, and each band's level of harmonics and of noise in the recordings and how far the synth is off, marking those beyond 30 percent or 6 dB.
  The recordings' figures are kept in the system's temporary folder and reused until a file changes.

      mx fit electric_piano --struck keyboard_electronic_098 --out electric_piano.mxf
      mx fit marimba --struck marimba.txt --check
      mx fit marimba --struck marimba.txt --tour marimba_tour.wav --count 8

  `--struck` with a folder of NSynth recordings, or a list of recordings with their notes and velocities, fits recordings of struck notes partial by partial instead, as `Mx.Fit.Struck` describes; it can be given more than once.
  `--out` writes the figures to a file, for mxs to play.
  `--notes` with two notes, such as `E1:E6`, keeps the recordings from the first to the second.
  `--check` renders the synth at each recording's note and velocity and prints how far it is from the recordings, each figure followed by the same figure for the fit's own render, the figures played with no synth, which is the closest the synth can come.
  The check also names the 50 ms furthest off in ERB bands, the note it is in and where it starts, as a sound can match on average over a note and still be far off for a moment of it.
  `--own` with `--check` prints the fit's figures alone and renders no synth, so it runs before the synth plays the figures.
  `--note` and `--vel` with `--check`, such as `--note C2 --vel 80`, print that one recording beside the synth and the fit's own render instead, frame by frame: each partial within 60 dB of the loudest and each ERB band, every 5 ms from 5 ms before the strike to 100 ms after, with the fit's sines and noise apart.
  `--until` with seconds carries the rows on to that time in 24 steps, and `--csv` with a file name also writes the figures as a table.
  `--tour` writes a WAV file of twelve recordings, or as many as `--count` gives, each followed by the synth.
  `--top` with a frequency in Hz, such as `--top 16000`, follows the partials and fits the strike's noise up to it instead of 8 kHz, for an instrument that is bright above that, such as a drum with jingles.
  `--option` with a synth's option and its value, such as `--option pedal=1`, renders the synth with it in `--check` and `--tour`; it can be given more than once.

      mx fit clarinet --held clarinet.txt --out clarinet.mxh
      mx fit clarinet --held clarinet.txt --check

  `--held` with a list fits recordings of held notes partial by partial, bowed or blown, as `Mx.Fit.Held` describes, and takes the same options except `--note` and `--vel`.
  `--steady` with `--held` holds each note at one level from where it starts holding, for recordings that ease off before they are let go, as the University of Iowa's flute does.
  Its check compares each partial over the attack and on average where the note holds, and the ERB bands until a second after the note is let go, with the synth held as long as the recording.
  The guide on instruments, under "Fitting a struck instrument", describes the list and what the check prints.
  """

  use Mix.Task

  alias Mx.{Fit, Measure, Notes, Signal, Synths}
  alias Mx.Fit.{Held, Struck}

  @example "BbClar.pp.D3B3.aiff:D3"

  @impl true
  def run(args) when is_list(args) do
    Mx.Command.config()
    {synth, rest} = synth!(args)

    cond do
      "--struck" in rest -> struck(synth, rest, :struck)
      "--held" in rest -> struck(synth, rest, :held)
      true -> held(synth, rest)
    end
  end

  defp held(synth, rest) do
    parsed = parse!(rest, %{dynamics: [], controls: [], from: 0, check: false, drone: false})

    dynamics =
      Enum.map(Enum.reverse(parsed.dynamics), fn {vel, files} -> {vel, Enum.reverse(files)} end)

    controls = parsed.controls |> Enum.reverse() |> Enum.map(&control!(synth, &1))

    if dynamics == [] do
      Mx.Command.fail("give each dynamic as --vel and its files, such as --vel 0.3 #{@example}")
    end

    if controls == [] and not parsed.check do
      Mx.Command.fail("give each control to fit, such as --control k_odd=-2:2")
    end

    recorded = recordings!(dynamics, parsed.drone)
    lowest = Fit.lowest(dynamics)
    highest = recorded |> Enum.map(& &1.highest) |> Enum.max()
    notes = Enum.to_list(lowest..highest)
    values = for control <- controls, do: {control.name, control.value}

    if parsed.check do
      check(synth, recorded, notes, parsed.from, values)
    else
      {best, score} = Fit.search(synth, recorded, notes, parsed.from, controls, &report/1)

      IO.puts(
        "best #{decimals(score)}: " <>
          Enum.map_join(best, " ", fn {name, value} -> "#{name}=#{number(value)}" end)
      )
    end
  end

  defp struck(synth, rest, kind) do
    fitter = if kind == :held, do: Held, else: Struck

    {opts, extra} =
      OptionParser.parse!(rest,
        strict: [
          struck: :keep,
          held: :keep,
          out: :string,
          notes: :string,
          check: :boolean,
          own: :boolean,
          note: :string,
          vel: :integer,
          until: :float,
          csv: :string,
          tour: :string,
          count: :integer,
          option: :keep,
          steady: :boolean,
          top: :float
        ]
      )

    check_flags!(kind, opts, extra)
    notes = opts[:notes] && notes!(opts[:notes])
    options = opts |> Keyword.get_values(:option) |> Enum.map(&given_option!(synth, &1))

    recordings =
      opts
      |> Keyword.get_values(kind)
      |> Enum.flat_map(&struck_recordings!(&1, notes, kind))
      |> Enum.sort_by(&{&1.note, &1.velocity})
      |> topped(opts[:top])

    if out = opts[:out] do
      figures = figures(kind, recordings, opts)
      File.write!(out, figures)
      count = length(recordings)
      bytes = byte_size(figures)
      IO.puts("wrote the figures of #{count} recordings to #{out}, #{bytes} bytes")
    end

    cond do
      opts[:note] ->
        print_frames(!opts[:own] && synth, recordings, opts, options)

      opts[:own] ->
        print_struck(own(kind, recordings, opts), "the fit's own render", "the fit", kind)

      opts[:check] ->
        checks =
          Struck.beside(fitter.check(synth, recordings, options), own(kind, recordings, opts))

        print_struck(checks, synth, "synth", kind)

      true ->
        :ok
    end

    if tour = opts[:tour] do
      {data, rate} = fitter.tour(synth, recordings, opts[:count] || 12, options)
      Mx.Audio.write_floats(tour, data, rate)
      count = min(opts[:count] || 12, length(recordings))
      IO.puts("wrote a tour of #{count} recordings, each followed by #{synth}, to #{tour}")
    end
  end

  defp figures(:held, recordings, opts), do: Held.figures(recordings, steady: !!opts[:steady])
  defp figures(:struck, recordings, _opts), do: Struck.figures(recordings)

  defp own(:held, recordings, opts), do: Held.own(recordings, steady: !!opts[:steady])
  defp own(:struck, recordings, _opts), do: Struck.own(recordings)

  defp check_flags!(kind, opts, extra) do
    files = Enum.join(extra, " ")

    cond do
      extra != [] ->
        Mx.Command.fail("--#{kind} takes a folder or a list, not files: #{files}")

      kind == :held and opts[:note] ->
        Mx.Command.fail("--note and --vel go with --struck, not --held")

      opts[:top] && kind == :held ->
        Mx.Command.fail("--top goes with --struck, not --held")

      opts[:top] && opts[:top] < 1000 ->
        top = opts[:top]
        Mx.Command.fail("give --top as a frequency of 1000 Hz or more, not #{top}")

      kind == :struck and opts[:steady] ->
        Mx.Command.fail("--steady goes with --held, not --struck")

      true ->
        check_outputs!(opts)
    end
  end

  defp check_outputs!(opts) do
    cond do
      !(opts[:out] || opts[:check] || opts[:tour]) ->
        Mx.Command.fail(
          "give --out with a file to write the figures to, --check, or --tour with a file to write a tour to"
        )

      opts[:own] && !opts[:check] ->
        Mx.Command.fail("--own needs --check")

      (opts[:note] || opts[:vel]) && !(opts[:check] && opts[:note] && opts[:vel]) ->
        Mx.Command.fail("--note and --vel go together, with --check")

      (opts[:until] || opts[:csv]) && !opts[:note] ->
        Mx.Command.fail("--until and --csv need --note and --vel")

      true ->
        :ok
    end
  end

  defp given_option!(synth, text) do
    with [name, value] <- String.split(text, "="),
         {number, ""} <- Float.parse(value) do
      {option!(synth, name), number}
    else
      _ -> Mx.Command.fail("give --option as a name and a number, such as pedal=1, not #{text}")
    end
  end

  defp topped(recordings, nil), do: recordings
  defp topped(recordings, top), do: Enum.map(recordings, &Map.put(&1, :top, top))

  defp struck_recordings!(path, notes, kind) do
    found =
      cond do
        kind == :held and File.dir?(path) ->
          {:error, "--held takes a list, not a folder: #{path}"}

        File.dir?(path) ->
          Struck.recordings(path, notes)

        kind == :held ->
          Held.listed(path, notes)

        true ->
          Struck.listed(path, notes)
      end

    case found do
      {:ok, recordings} ->
        recordings

      {:ok, recordings, lines} ->
        Enum.each(lines, &print_line/1)
        recordings

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp print_line(line) do
    name = Path.basename(line.path)
    found = Enum.map_join(line.found, " ", &Measure.name/1)
    IO.puts("#{name}: #{found}")

    for {note, seconds, why} <- line.left_out do
      note = Measure.name(note)
      at = :erlang.float_to_binary(seconds, decimals: 1)
      IO.puts("  left out #{note} at #{at} s: #{why}")
    end

    if line.missing != [] do
      missing = Enum.map_join(line.missing, " ", &Measure.name/1)
      IO.puts("  not found: #{missing}")
    end
  end

  defp print_struck(checks, heading, render, kind) do
    first = if kind == :held, do: "over the attack", else: "over the first 20 ms"
    first_short = if kind == :held, do: "attack", else: "first 20 ms"
    average = if kind == :held, do: "on average where it holds", else: "on average"
    %{strong: strong, weaker: weaker, erb: erb} = Struck.summary(checks)
    fit = Map.has_key?(hd(checks), :own) && Struck.summary(Enum.map(checks, & &1.own))
    count = length(checks)
    IO.puts("#{heading} against #{count} recordings")

    strike = percent(strong.strike) <> " within 2 dB #{first}"
    strike = strike <> the_fit(fit && percent(fit.strong.strike))
    mean = percent(strong.mean) <> " within 2 dB #{average}"
    mean = mean <> the_fit(fit && percent(fit.strong.mean))
    IO.puts("#{strong.count} partials within 30 dB of the loudest: #{strike}, #{mean}")

    mean = percent(weaker.mean) <> " within 4 dB on average"
    mean = mean <> the_fit(fit && percent(fit.weaker.mean))
    IO.puts("#{weaker.count} partials 30 to 60 dB down: #{mean}")

    median =
      decimals(erb.median) <> " dB at the median note" <> the_fit(fit && decimals(fit.erb.median))

    note = checks |> Struck.furthest_notes(1) |> hd() |> Struck.label()

    worst =
      decimals(erb.worst) <>
        " dB at the worst, #{note}" <> the_fit(fit && decimals(fit.erb.worst))

    IO.puts("ERB bands: #{median}; #{worst}")
    print_stretch(checks, kind)
    print_pitch(Struck.pitch(checks), render)
    print_partials(checks, first_short)

    print_loudness(
      Struck.loudness(checks),
      fit && Struck.loudness(Enum.map(checks, & &1.own)),
      render
    )

    print_notes(checks)
    print_room(checks)
  end

  defp print_room(checks) do
    rooms = checks |> Enum.filter(&(Map.get(&1, :room, []) != [])) |> Enum.uniq_by(& &1.path)

    if rooms != [] do
      names = Enum.map(rooms, &Path.basename(&1.path))
      width = names |> Enum.map(&String.length/1) |> Enum.max()

      IO.puts(
        "\nthe room of each file, in dB of a sine at full scale, at each ERB band's centre in Hz"
      )

      centres =
        Enum.map(hd(rooms).bands, fn {centre, _, _} -> Integer.to_string(round(centre)) end)

      IO.puts(room_line("Hz", centres, width))

      for {name, check} <- Enum.zip(names, rooms) do
        IO.puts(
          room_line(name, Enum.map(check.room, &:erlang.float_to_binary(&1, decimals: 1)), width)
        )
      end
    end
  end

  defp room_line(name, figures, width) do
    String.pad_trailing(name, width) <> Enum.map_join(figures, &String.pad_leading(&1, 7))
  end

  defp print_partials(checks, first_short) do
    IO.puts("\nthe ten partials furthest off on average:")

    for partial <- Struck.furthest_partials(checks, 10) do
      note = Struck.label(partial)
      ratio = :erlang.float_to_binary(partial.ratio, decimals: 3)
      which = if partial.harmonic > 0, do: "harmonic #{partial.harmonic}", else: "between"
      below = decimals(partial.below)
      own = partial[:own]

      strike =
        signed_decimals(partial.strike) <> " dB" <> the_fit(own && signed_decimals(own.strike))

      mean = decimals(partial.mean) <> " dB" <> the_fit(own && decimals(own.mean))

      IO.puts(
        "  #{note}, #{ratio} #{which}, #{below} dB down: #{first_short} #{strike}, mean #{mean}"
      )
    end
  end

  defp print_notes(checks) do
    IO.puts("\nthe ten notes furthest off in ERB bands:")

    for check <- Struck.furthest_notes(checks, 10) do
      note = Struck.label(check)
      own = check[:own]
      erb = decimals(check.erb) <> " dB" <> the_fit(own && decimals(own.erb))
      off = Integer.to_string(off(check))
      off = off <> " of its partials within 30 dB of the loudest more than 2 dB off"
      off = off <> the_fit(own && Integer.to_string(off(own)))
      IO.puts("  #{note}: #{erb}; #{off}")
    end
  end

  defp print_frames(synth, recordings, opts, options) do
    note = note!(opts[:note])
    recording = recording!(recordings, note, opts[:vel])
    times = times(opts[:until])
    frames = Struck.frames(synth || nil, recording, times, options)

    cents =
      :erlang.float_to_binary(1200 * :math.log2(frames.pitch / Signal.hz(note)), decimals: 1)

    pitch = :erlang.float_to_binary(frames.pitch, decimals: 2)
    strike = :erlang.float_to_binary(frames.strike, decimals: 3)
    label = Struck.label(recording)
    name = Measure.name(note)
    file = Path.basename(recording.path)

    IO.puts(
      "#{label}: #{pitch} Hz, #{cents} cents from #{name}, struck at #{strike} s in #{file}"
    )

    IO.puts(
      "levels in dB against the loudest partial over the first 20 ms, - at or under the recording's floor\n"
    )

    milliseconds = Enum.map(times, &round(&1 * 1000))
    IO.puts(row_line("ms", Enum.map(milliseconds, &Integer.to_string/1)))

    for rows <- frames.partials, do: print_rows(partial_name(rows.at), rows)
    IO.puts("\nERB bands")
    for rows <- frames.bands, do: print_rows(band_name(rows.at), rows)

    if csv = opts[:csv] do
      File.write!(csv, csv(frames, milliseconds))
      IO.puts("\nwrote the figures to #{csv}")
    end
  end

  defp recording!(recordings, note, velocity) do
    case Enum.find(recordings, &(&1.note == note and &1.velocity == velocity)) do
      nil ->
        nearest = Enum.min_by(recordings, &{abs(&1.note - note), abs(&1.velocity - velocity)})
        wanted = Struck.label(%{note: note, velocity: velocity})
        nearest = Struck.label(nearest)
        Mx.Command.fail("no recording of #{wanted}; the nearest is #{nearest}")

      recording ->
        recording
    end
  end

  # Every 5 ms from 5 ms before the strike to 100 ms after, or 24 steps to `until`, each at a
  # frame of the measuring, 2.5 ms apart.
  defp times(nil) do
    for step <- 0..21, do: (5 * step - 5) / 1000
  end

  defp times(until) do
    for step <- 0..23 do
      at = -0.005 + step * (until + 0.005) / 23
      Float.round(round((at + 0.005) / 0.0025) * 0.0025 - 0.005, 4)
    end
  end

  defp partial_name({ratio, harmonic}) do
    ratio = :erlang.float_to_binary(ratio, decimals: 3)
    kind = if harmonic > 0, do: "harmonic #{round(harmonic)}", else: "between"
    "#{ratio} #{kind}"
  end

  defp band_name({low, high}), do: "#{round(low)}-#{round(high)} Hz"

  defp print_rows(name, %{rows: rows, floor: floor}) do
    IO.puts(name)

    for {row, levels} <- rows do
      IO.puts(row_line(row_name(row), Enum.map(levels, &level(&1, floor))))
    end
  end

  defp row_name("fit"), do: "  the fit"
  defp row_name(row) when row in ["sines", "noise", "room"], do: "    #{row}"
  defp row_name(row), do: "  #{row}"

  defp row_line(name, figures) do
    String.pad_trailing(name, 12) <> Enum.map_join(figures, &String.pad_leading(&1, 7))
  end

  defp level(level, floor) when level <= floor, do: "-"
  defp level(level, _floor), do: :erlang.float_to_binary(level, decimals: 1)

  defp csv(frames, milliseconds) do
    lines =
      for {kind, all, name} <- [
            {"partial", frames.partials, &partial_name/1},
            {"band", frames.bands, &band_name/1}
          ],
          rows <- all,
          {row, levels} <- rows.rows,
          {ms, level} <- Enum.zip(milliseconds, levels) do
        figure = level(level, rows.floor)
        figure = if figure == "-", do: "", else: figure
        at = name.(rows.at)
        "#{kind},#{at},#{row},#{ms},#{figure}"
      end

    Enum.join(["kind,at,row,ms,db" | lines], "\n") <> "\n"
  end

  defp print_pitch(pitch, render) do
    recordings = signed_cents(pitch.recordings)
    rendered = signed_cents(elem(pitch.furthest.pitch, 1))
    furthest = Struck.label(pitch.furthest)
    median = signed_cents(pitch.render)

    IO.puts(
      "pitch: the recordings #{recordings} cents from their names at the median note, #{render} #{median}, furthest at #{furthest}, #{rendered}"
    )

    for check <- pitch.off do
      note = Struck.label(check)
      cents = signed_cents(elem(check.pitch, 1))
      IO.puts("  #{render} plays #{note} #{cents} cents from its name")
    end
  end

  defp signed_cents(cents) when cents >= 0, do: "+" <> :erlang.float_to_binary(cents, decimals: 1)
  defp signed_cents(cents), do: :erlang.float_to_binary(cents, decimals: 1)

  defp off(check), do: Enum.count(check.partials, &(&1.below <= 30 and &1.mean > 2))

  defp print_stretch(checks, kind) do
    furthest = Enum.max_by(checks, &elem(&1.stretch, 0))
    {gap, from} = furthest.stretch
    gap = decimals(gap)
    ms = round(from * 1000)
    after_what = if kind == :held, do: "the note starts", else: "the strike"
    note = Struck.label(furthest)
    own = furthest[:own] && decimals(elem(furthest.own.stretch, 0))
    fit = the_fit(own)
    IO.puts("furthest off over 50 ms: #{gap} dB from #{ms} ms after #{after_what}, #{note}#{fit}")
  end

  defp the_fit(nil), do: ""
  defp the_fit(false), do: ""
  defp the_fit(text), do: ", the fit #{text}"

  defp print_loudness([], _fit, _render), do: :ok

  defp print_loudness(rows, fit, render) do
    IO.puts("\neach velocity under the loudest at its note, over the first half second:")

    for {row, own} <- Enum.zip(rows, fit || List.duplicate(nil, length(rows))) do
      note = Measure.name(row.note)
      recording = signed_decimals(row.recording)

      rendered =
        signed_decimals(row.render) <>
          " dB" <> the_fit(own && signed_decimals(own.render) <> " dB")

      IO.puts("  #{note} vel #{row.velocity}: recordings #{recording} dB, #{render} #{rendered}")
    end
  end

  defp notes!(text) do
    case String.split(text, ":") do
      [low, high] -> note!(low)..note!(high)//1
      _other -> Mx.Command.fail("give --notes as two notes, such as --notes E1:E6")
    end
  end

  defp percent(nil), do: "-"

  defp percent(share) do
    percent = round(share * 100)
    "#{percent}%"
  end

  defp recordings!(dynamics, drone) do
    case Fit.recordings(dynamics, drone) do
      {:error, message} ->
        Mx.Command.fail(message)

      {:ok, recorded, cached} ->
        if cached, do: IO.puts("using the recordings' figures from an earlier run")

        for dynamic <- recorded do
          below = "#{dynamic.below} below #{Measure.name(Fit.lowest(dynamics))}"

          IO.puts(
            "vel #{number(dynamic.vel)}: #{dynamic.notes} notes, left out #{dynamic.quiet} quiet stretches and #{below}"
          )
        end

        recorded
    end
  end

  defp check(synth, recorded, notes, from, values) do
    misses = Fit.misses(synth, recorded, notes, from, values)

    for %{vel: vel, attack: attack, bands: bands, noise: noise} <- misses do
      IO.puts("vel #{number(vel)} attack #{attack(attack)}")

      for {kind, rows} <- [{"", bands}, {" noise", noise}],
          {{low, high}, level, difference} <- rows do
        flag = if abs(difference) > 6, do: " <--", else: ""
        recorded = signed_decimals(level)
        missed = signed_decimals(difference)

        IO.puts(
          "vel #{number(vel)} #{low}-#{high} Hz#{kind} recordings #{recorded} dB, off by #{missed} dB#{flag}"
        )
      end
    end

    IO.puts("score #{decimals(Fit.score(misses))}")
  end

  defp attack(nil), do: "-"

  defp attack(attack) do
    percent = signed(round(attack * 100))
    flag = if abs(attack) > 0.3, do: " <--", else: ""
    "#{percent}%#{flag}"
  end

  defp report({:start, score}), do: IO.puts("start #{decimals(score)}")
  defp report({:round, round}), do: IO.puts("round #{round}")

  defp report({:kept, name, value, score}) do
    IO.puts("  #{name} #{number(value)}: #{decimals(score)}")
  end

  defp synth!([name | rest]) do
    if String.starts_with?(name, "--") do
      Mx.Command.fail("give the synth first, such as mix mx.fit clarinet")
    end

    {Enum.find(Synths.synths(), &(&1 == name)) ||
       Mx.Command.fail("unknown synth #{name}"), rest}
  end

  defp synth!([]), do: Mx.Command.fail("give the synth first, such as mix mx.fit clarinet")

  defp parse!([], parsed), do: parsed

  defp parse!(["--vel", text | rest], parsed) do
    parse!(rest, %{parsed | dynamics: [{float!(text, "--vel"), []} | parsed.dynamics]})
  end

  defp parse!(["--from", text | rest], parsed) do
    parse!(rest, %{parsed | from: float!(text, "--from")})
  end

  defp parse!(["--control", text | rest], parsed) do
    parse!(rest, %{parsed | controls: [text | parsed.controls]})
  end

  defp parse!(["--check" | rest], parsed), do: parse!(rest, %{parsed | check: true})
  defp parse!(["--drone" | rest], parsed), do: parse!(rest, %{parsed | drone: true})
  defp parse!(["--" <> _ = flag | _rest], _parsed), do: Mx.Command.fail("unknown option #{flag}")

  defp parse!([file | rest], %{dynamics: [{vel, files} | dynamics]} = parsed) do
    parse!(rest, %{parsed | dynamics: [{vel, [file!(file) | files]} | dynamics]})
  end

  defp parse!([_file | _rest], _parsed) do
    Mx.Command.fail("give --vel before its files, such as --vel 0.3 #{@example}")
  end

  defp file!(arg) do
    case Regex.run(~r/^(.+):([^:]+)$/, arg) do
      [_, path, note] -> {path, note!(note)}
      nil -> Mx.Command.fail("give each file with the note it starts on, such as #{@example}")
    end
  end

  defp note!(text) do
    Notes.from_text(text)
  rescue
    ArgumentError -> Mx.Command.fail("unknown note #{text}")
  end

  defp control!(synth, text) do
    with [name, value, step] <- String.split(text, ["=", ":"]),
         {value, ""} <- Float.parse(value),
         {ratio, step} = ratio(step),
         {step, ""} <- Float.parse(step) do
      %{name: option!(synth, name), value: value, step: step, ratio: ratio}
    else
      _other ->
        Mx.Command.fail(
          "give --control as a name, a starting value and a step, such as --control k_odd=-2:2"
        )
    end
  end

  defp ratio("x" <> step), do: {true, step}
  defp ratio(step), do: {false, step}

  defp option!(synth, name) do
    if option = Synths.option(synth, name) do
      option
    else
      Mx.Command.fail("#{synth} takes no control #{name}")
    end
  end

  defp float!(text, flag) do
    case Float.parse(text) do
      {value, ""} -> value
      _other -> Mx.Command.fail("#{flag} takes a number, not #{text}")
    end
  end

  defp number(value) when value == trunc(value), do: Integer.to_string(trunc(value))
  defp number(value), do: value |> Float.round(4) |> Float.to_string()

  defp decimals(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)
  defp signed_decimals(value) when value >= 0, do: "+" <> decimals(value)
  defp signed_decimals(value), do: decimals(value)
  defp signed(value) when value >= 0, do: "+#{value}"
  defp signed(value), do: "#{value}"
end
