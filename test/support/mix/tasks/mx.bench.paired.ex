defmodule Mix.Tasks.Mx.Bench.Paired do
  @shortdoc "Times each paired instrument's defsynth form against its Rust form"

  @moduledoc """
  Times each instrument of `Mx.Paired.Twins` in its Rust form and its defsynth form, on an offline engine, and prints a row for each, the slowest defsynth form relative to Rust first.

      mix mx.bench.paired
      mix mx.bench.paired piano violin --runs 9
      mix mx.bench.paired --write tmp/paired.txt
      mix mx.bench.paired --compare tmp/paired.txt

  It lives in `test/support`, beside the twins, so it runs in the test environment and never ships.

  Each note of a twin's cases is played on a fresh engine, `--runs` times, 5 unless given, the two forms taking turns, and each figure is the median of the runs.
  The columns are the microseconds handing a note to the engine takes, which builds its voice, the milliseconds the engine's own meter says rendering a second of the note takes less what an engine without notes takes, the defsynth form's render time as a multiple of the Rust form's, and the milliseconds registering the defsynth form takes.
  The last line gives the geometric mean of the multiples.

  A sleeping scheduler of the VM can take 10 ms to wake for a call into the engine, more than building a voice takes, so the task refuses to run unless `ERL_FLAGS` asks for schedulers that wait busy:

      ERL_FLAGS="+sbwt very_long +sbwtdcpu very_long +sbwtdio very_long" mix mx.bench.paired

  The figures mean something only on a machine doing nothing else.

  `--write FILE` writes the figures to a file, and `--compare FILE` prints each figure that is worse than in such a file by more than a tenth, and nothing when none is.
  """

  use Mix.Task

  alias Mx.Bench
  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  @busy "+sbwt very_long +sbwtdcpu very_long +sbwtdio very_long"

  @impl true
  def run(args) do
    if String.contains?(System.get_env("ERL_FLAGS", ""), @busy) do
      measure_all(args)
    else
      Mx.Command.fail(~s(run it as ERL_FLAGS="#{@busy}" mix mx.bench.paired))
    end
  end

  defp measure_all(args) do
    {opts, synths} =
      OptionParser.parse!(args, strict: [runs: :integer, write: :string, compare: :string])

    {:ok, _apps} = Application.ensure_all_started(:mx)
    runs = Keyword.get(opts, :runs, 5)

    rows = for twin <- twins(synths), do: measure(twin, runs)
    rows = Enum.sort_by(rows, & &1.times, :desc)
    print(rows)

    figures = figures(rows)
    if opts[:write], do: Bench.write(opts[:write], figures)
    if opts[:compare], do: compare(opts[:compare], figures)
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

    timed =
      for options <- cases do
        event = Mxs.event({:note, nil, synth, nil, options, nil})

        samples =
          for _ <- 1..runs,
              do: {note(fresh(nil), event, seconds), note(fresh(module), event, seconds)}

        {rust, elixir} = Enum.unzip(samples)
        {medians(rust), medians(elixir)}
      end

    {rust, elixir} = Enum.unzip(timed)
    rust_ms = per_second(rust, empty)
    elixir_ms = per_second(elixir, empty)

    %{
      synth: synth,
      rust_build_us: built(rust),
      defsynth_build_us: built(elixir),
      rust_ms_per_second: rust_ms,
      defsynth_ms_per_second: elixir_ms,
      times: Float.round(elixir_ms / max(rust_ms, 0.001), 2),
      register_ms: median(for _ <- 1..runs, do: registered(module))
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

  defp medians(samples) do
    {builds, renders} = Enum.unzip(samples)
    {median(builds), median(renders)}
  end

  defp built(cases), do: round(Enum.sum(for {build, _render} <- cases, do: build) / length(cases))

  defp per_second(cases, empty) do
    ms = Enum.sum(for {_build, render} <- cases, do: render - empty)
    Float.round(ms / length(cases), 2)
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
    register_ms: "register ms"
  ]

  defp print(rows) do
    values = for row <- rows, do: Enum.map(Keyword.keys(@columns), &cell(row[&1]))
    cells = [Keyword.values(@columns) | values]

    widths =
      cells
      |> Enum.zip_with(& &1)
      |> Enum.map(fn column -> Enum.max(Enum.map(column, &String.length/1)) end)

    for [name | figures] <- cells do
      [width | rest] = widths
      padded = Enum.zip_with(figures, rest, &String.pad_leading/2)
      IO.puts(Enum.join([String.pad_trailing(name, width) | padded], "  "))
    end

    mean = :math.exp(Enum.sum(for row <- rows, do: :math.log(max(row.times, 0.1))) / length(rows))
    rounded = Float.round(mean, 1)
    IO.puts("\ngeometric mean of ×: #{rounded}")
  end

  defp cell(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp cell(value), do: to_string(value)

  defp figures(rows) do
    for row <- rows, {key, _title} <- @columns, key != :synth, into: %{} do
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
