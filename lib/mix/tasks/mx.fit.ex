defmodule Mix.Tasks.Mx.Fit do
  @shortdoc "Fits a synth to recordings of held notes by its controls, or of struck notes partial by partial"

  @moduledoc """
  Searches for the values of a synth's controls that bring its held notes closest to recordings of them, as `Mx.Fit` describes.

      mix mx.fit clarinet --vel 0.3 BbClar.pp.D3B3.aiff:D3 BbClar.pp.C4B4.aiff:C4 --vel 1 BbClar.ff.D3B3.aiff:D3 --from 160 --control k_odd=-2:2 --control k_att=0.15:x1.15

  The synth comes first, then each dynamic as `--vel` and the files played at it, each with the note it starts on, as `mix mx.measure` takes them.
  `--control` gives a control the synth takes, its starting value and its step, such as `k_odd=-2:2`; a step written with an x, such as `x1.15`, multiplies and divides instead of adding and subtracting.
  `--from` gives the lowest frequency in Hz of the bands compared, all of them below 4 kHz unless given.
  It prints how many notes it kept at each dynamic and how many it left out, the score it starts from, each change it keeps, and the best values at the end.
  `--drone` measures each file as one note held from its first sample to its last, for a drone plucked again and again, which would otherwise read as a note at each pluck, and leaves out the attack.
  `--check` scores the starting values instead of searching, and needs no control; it prints each dynamic's attack difference, and each band's level of harmonics and of noise in the recordings and how far the synth is off, marking those beyond 30 percent or 6 dB.
  The recordings' figures are kept in the system's temporary folder and reused until a file changes.

      mix mx.fit electric_piano --struck keyboard_electronic_098 --out electric_piano.mxf
      mix mx.fit marimba --struck marimba.txt --check
      mix mx.fit marimba --struck marimba.txt --tour marimba_tour.wav --count 8

  `--struck` with a folder of NSynth recordings, or a list of recordings with their notes and velocities, fits recordings of struck notes partial by partial instead, as `Mx.Fit.Struck` describes; it can be given more than once.
  `--out` writes the figures to a file, for mxs to play.
  `--notes` with two notes, such as `E1:E6`, keeps the recordings from the first to the second.
  `--check` renders the synth at each recording's note and velocity and prints how far it is from the recordings.
  `--tour` writes a WAV file of twelve recordings, or as many as `--count` gives, each followed by the synth.
  The guide on instruments, under "Fitting a struck instrument", describes the list and what the check prints.
  """

  use Mix.Task

  alias Mx.{Fit, Measure, Notes, Synths}
  alias Mx.Fit.Struck

  @example "BbClar.pp.D3B3.aiff:D3"

  @impl true
  def run(args) when is_list(args) do
    Mx.Command.config()
    {synth, rest} = synth!(args)
    if "--struck" in rest, do: struck(synth, rest), else: held(synth, rest)
  end

  defp held(synth, rest) do
    parsed = parse!(rest, %{dynamics: [], controls: [], from: 0, check: false, drone: false})

    dynamics =
      Enum.reverse(parsed.dynamics) |> Enum.map(fn {vel, files} -> {vel, Enum.reverse(files)} end)

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

  defp struck(synth, rest) do
    {opts, extra} =
      OptionParser.parse!(rest,
        strict: [
          struck: :keep,
          out: :string,
          notes: :string,
          check: :boolean,
          tour: :string,
          count: :integer
        ]
      )

    files = Enum.join(extra, " ")

    if extra != [],
      do: Mx.Command.fail("--struck takes a folder or a list, not files: #{files}")

    if !opts[:out] and !opts[:check] and !opts[:tour],
      do:
        Mx.Command.fail(
          "give --out with a file to write the figures to, --check, or --tour with a file to write a tour to"
        )

    notes = opts[:notes] && notes!(opts[:notes])

    recordings =
      opts
      |> Keyword.get_values(:struck)
      |> Enum.flat_map(&struck_recordings!(&1, notes))
      |> Enum.sort_by(&{&1.note, &1.velocity})

    if out = opts[:out] do
      figures = Struck.figures(recordings)
      File.write!(out, figures)
      count = length(recordings)
      bytes = byte_size(figures)
      IO.puts("wrote the figures of #{count} recordings to #{out}, #{bytes} bytes")
    end

    if opts[:check], do: print_struck(synth, recordings)

    if tour = opts[:tour] do
      {data, rate} = Struck.tour(synth, recordings, opts[:count] || 12)
      Mx.Audio.write_floats(tour, data, rate)
      count = min(opts[:count] || 12, length(recordings))
      IO.puts("wrote a tour of #{count} recordings, each followed by #{synth}, to #{tour}")
    end
  end

  defp struck_recordings!(path, notes) do
    found =
      if File.dir?(path), do: Struck.recordings(path, notes), else: Struck.listed(path, notes)

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

  defp print_struck(synth, recordings) do
    checks = Struck.check(synth, recordings)
    %{strong: strong, weaker: weaker, erb: erb} = Struck.summary(checks)
    count = length(checks)
    IO.puts("#{synth} against #{count} recordings")

    strike = percent(strong.strike)
    mean = percent(strong.mean)

    IO.puts(
      "#{strong.count} partials within 30 dB of the loudest: #{strike} within 2 dB over the first 20 ms, #{mean} within 2 dB on average"
    )

    mean = percent(weaker.mean)
    IO.puts("#{weaker.count} partials 30 to 60 dB down: #{mean} within 4 dB on average")

    median = decimals(erb.median)
    worst = decimals(erb.worst)
    note = checks |> Struck.furthest_notes(1) |> hd() |> Struck.label()
    IO.puts("ERB bands: #{median} dB at the median note, #{worst} dB at the worst, #{note}")
    IO.puts("\nthe ten partials furthest off on average:")

    for partial <- Struck.furthest_partials(checks, 10) do
      note = Struck.label(partial)
      ratio = :erlang.float_to_binary(partial.ratio, decimals: 3)
      kind = if partial.harmonic > 0, do: "harmonic #{partial.harmonic}", else: "between"
      below = decimals(partial.below)
      strike = signed_decimals(partial.strike)
      mean = decimals(partial.mean)

      IO.puts(
        "  #{note}, #{ratio} #{kind}, #{below} dB down: first 20 ms #{strike} dB, mean #{mean} dB"
      )
    end

    print_loudness(Struck.loudness(checks))
    IO.puts("\nthe ten notes furthest off in ERB bands:")

    for check <- Struck.furthest_notes(checks, 10) do
      note = Struck.label(check)
      erb = decimals(check.erb)
      off = Enum.count(check.partials, &(&1.below <= 30 and &1.mean > 2))

      IO.puts(
        "  #{note}: #{erb} dB, #{off} of its partials within 30 dB of the loudest more than 2 dB off"
      )
    end
  end

  defp print_loudness([]), do: :ok

  defp print_loudness(rows) do
    IO.puts("\neach velocity under the loudest at its note, over the first half second:")

    for row <- rows do
      note = Measure.name(row.note)
      recording = signed_decimals(row.recording)
      render = signed_decimals(row.render)
      IO.puts("  #{note} vel #{row.velocity}: recordings #{recording} dB, synth #{render} dB")
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

  # Every control a synth takes is already an atom, so a name that is not one is no control.
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
