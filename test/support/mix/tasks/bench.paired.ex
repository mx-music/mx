defmodule Mix.Tasks.Bench.Paired do
  @shortdoc "Times each paired instrument's defsynth form against its Rust form"

  @moduledoc """
  Times each instrument of `Mx.Paired.Twins` in its Rust form and its defsynth form, on an offline engine, and prints a row for each, the slowest defsynth form relative to Rust first.

      mix bench.paired
      mix bench.paired piano violin --runs 9
      mix bench.paired --write tmp/paired.txt
      mix bench.paired --compare tmp/paired.txt

  It lives in `test/support`, beside the twins, so it runs in the test environment and never ships.

  Each note of a twin's cases is played on a fresh engine, `--runs` times, 5 unless given, the two forms taking turns, and each figure is the median of the runs.
  The columns are the microseconds handing a note to the engine takes, which builds its voice, the milliseconds the engine's own meter says rendering a second of the note takes less what an engine without notes takes, the defsynth form's render time as a multiple of the Rust form's, and the milliseconds registering the defsynth form takes.
  The last line gives the geometric mean of the multiples.

  A sleeping scheduler of the VM can take 10 ms to wake for a call into the engine, more than building a voice takes, so the task refuses to run unless `ERL_FLAGS` asks for schedulers that wait busy:

      ERL_FLAGS="+sbwt very_long +sbwtdcpu very_long +sbwtdio very_long" mix bench.paired

  The figures mean something only on a machine doing nothing else.

  The last column is how far apart the runs' render times are, as a percentage of their median, for the case of the twin where they are furthest apart; a large one means the machine was busy.

  `--report FILE` writes the figures, each case's included, as an HTML page to read, with the machine, the commit and mxs's version they were measured on.
  `--write FILE` writes the figures to a file, and `--compare FILE` prints each figure that is worse than in such a file by more than a tenth, and nothing when none is.
  """

  use Mix.Task

  alias Mx.Bench
  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  @busy "+sbwt very_long +sbwtdcpu very_long +sbwtdio very_long"

  @impl true
  def run(args) do
    if "ERL_FLAGS" |> System.get_env("") |> String.contains?(@busy) do
      measure_all(args)
    else
      Mx.Command.fail(~s(run it as ERL_FLAGS="#{@busy}" mix bench.paired))
    end
  end

  defp measure_all(args) do
    {opts, synths} =
      OptionParser.parse!(args,
        strict: [runs: :integer, write: :string, compare: :string, report: :string]
      )

    {:ok, _apps} = Application.ensure_all_started(:mx)
    runs = Keyword.get(opts, :runs, 5)

    rows = for twin <- twins(synths), do: measure(twin, runs)
    rows = Enum.sort_by(rows, & &1.times, :desc)
    print(rows)

    figures = figures(rows)
    if opts[:write], do: Bench.write(opts[:write], figures)
    if opts[:compare], do: compare(opts[:compare], figures)
    if opts[:report], do: File.write!(opts[:report], Mx.Paired.Report.html(rows, context(runs)))
  end

  defp context(runs) do
    {commit, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
    {changed, 0} = System.cmd("git", ["status", "--porcelain", "--untracked-files=no"])

    [_whole, mxs] =
      Regex.run(~r/name = "mxs"\nversion = "([^"]+)"/, File.read!("native/mxs_nif/Cargo.lock"))

    {machine, 0} = System.cmd("sysctl", ["-n", "hw.model", "machdep.cpu.brand_string", "hw.ncpu"])
    [model, cpu, cores] = String.split(machine, "\n", trim: true)

    %{
      date: Date.utc_today(),
      commit: String.trim(commit),
      changed: changed != "",
      mxs: mxs,
      machine: "#{cpu}, #{cores} cores (#{model})",
      runs: runs
    }
  end

  defp twins([]), do: Mx.Paired.Twins.all()

  defp twins(names) do
    twins =
      for {_module, synth, _cases, _seconds} = twin <- Mx.Paired.Twins.all(),
          Atom.to_string(synth) in names,
          do: twin

    if twins == [], do: Mx.Command.fail("no paired instrument named #{Enum.join(names, ", ")}")
    twins
  end

  defp measure({module, synth, cases, seconds}, runs) do
    empty = median(for _ <- 1..runs, do: rendered(fresh(nil), seconds))
    cases = for options <- cases, do: measure_case(module, synth, options, seconds, runs, empty)
    rust_ms = mean(cases, :rust_ms_per_second)
    elixir_ms = mean(cases, :defsynth_ms_per_second)

    %{
      synth: synth,
      cases: cases,
      rust_build_us: round(mean(cases, :rust_build_us)),
      defsynth_build_us: round(mean(cases, :defsynth_build_us)),
      rust_ms_per_second: rust_ms,
      defsynth_ms_per_second: elixir_ms,
      times: times(elixir_ms, rust_ms),
      register_ms: median(for _ <- 1..runs, do: registered(module)),
      spread_percent: Enum.max(for case <- cases, do: case.spread_percent)
    }
  end

  defp measure_case(module, synth, options, seconds, runs, empty) do
    event = Mxs.event({:note, nil, synth, nil, options, nil})

    samples =
      for _ <- 1..runs,
          do: {note(fresh(nil), event, seconds), note(fresh(module), event, seconds)}

    {rust, elixir} = Enum.unzip(samples)
    {rust_builds, rust_renders} = Enum.unzip(rust)
    {elixir_builds, elixir_renders} = Enum.unzip(elixir)
    rust_ms = Float.round(median(rust_renders) - empty, 2)
    elixir_ms = Float.round(median(elixir_renders) - empty, 2)

    %{
      options: options,
      rust_build_us: median(rust_builds),
      defsynth_build_us: median(elixir_builds),
      rust_ms_per_second: rust_ms,
      defsynth_ms_per_second: elixir_ms,
      times: times(elixir_ms, rust_ms),
      spread_percent: max(spread(rust_renders), spread(elixir_renders))
    }
  end

  defp fresh(module) do
    {:ok, engine} = Native.start(false, false)
    if module, do: :ok = Mx.Instrument.register(engine, module)
    engine
  end

  defp note(engine, event, seconds) do
    {build, :ok} = :timer.tc(fn -> Native.play(engine, [{0.0, event}]) end)
    {build, rendered(engine, seconds)}
  end

  defp rendered(engine, seconds) do
    {:ok, _sound} = Native.render(engine, seconds)
    {_buffers, mean, _worst, _late} = Native.buffer_load(engine)
    mean * 1000
  end

  defp registered(module) do
    {:ok, engine} = Native.start(false, false)
    {micros, :ok} = :timer.tc(fn -> Mx.Instrument.register(engine, module) end)
    micros / 1000
  end

  defp mean(cases, key) do
    average = Enum.sum_by(cases, & &1[key]) / length(cases)
    Float.round(average, 2)
  end

  defp times(elixir_ms, rust_ms), do: Float.round(elixir_ms / max(rust_ms, 0.001), 2)

  # How far apart the runs' render times are, as a percentage of their median.
  defp spread(renders) do
    {fastest, slowest} = Enum.min_max(renders)
    round((slowest - fastest) / max(median(renders), 0.001) * 100)
  end

  defp median(values) do
    sorted = Enum.sort(values)
    Enum.at(sorted, div(length(sorted), 2))
  end

  @columns [
    synth: "synth",
    rust_build_us: "rust build µs",
    defsynth_build_us: "defsynth build µs",
    rust_ms_per_second: "rust ms/s",
    defsynth_ms_per_second: "defsynth ms/s",
    times: "×",
    register_ms: "register ms",
    spread_percent: "spread %"
  ]

  defp print(rows) do
    values = for row <- rows, do: @columns |> Keyword.keys() |> Enum.map(&cell(row[&1]))
    cells = [Keyword.values(@columns) | values]

    widths =
      cells
      |> Enum.zip_with(& &1)
      |> Enum.map(fn column -> column |> Enum.map(&String.length/1) |> Enum.max() end)

    for [name | figures] <- cells do
      [width | rest] = widths
      padded = Enum.zip_with(figures, rest, &String.pad_leading/2)
      [String.pad_trailing(name, width) | padded] |> Enum.join("  ") |> IO.puts()
    end

    log_mean = Enum.sum_by(rows, &:math.log(max(&1.times, 0.1))) / length(rows)
    mean = :math.exp(log_mean)
    rounded = Float.round(mean, 1)
    IO.puts("\ngeometric mean of ×: #{rounded}")
  end

  defp cell(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp cell(value), do: to_string(value)

  defp figures(rows) do
    for row <- rows, {key, _title} <- @columns, key not in [:synth, :spread_percent], into: %{} do
      {"paired/#{row.synth}/#{key}", row[key]}
    end
  end

  defp compare(path, figures) do
    case Bench.read(path) do
      {:ok, before} ->
        for {name, was, now} <- Bench.worse(before, figures),
            do: IO.puts("worse: #{name} was #{was} and is #{now}")

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end
end
