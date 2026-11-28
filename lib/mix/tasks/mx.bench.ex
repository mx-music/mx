defmodule Mix.Tasks.Mx.Bench do
  @shortdoc "Measures whether a song's notes reach the engine in time"

  @moduledoc """
  Measures how a song plays, as `Mx.Bench` works it out, against an offline engine, so nothing
  sounds.

      mix mx.bench lead examples/choro.exs
      mix mx.bench saves examples/trap.exs --at 5,10,15
      mix mx.bench buffers examples/choro.exs examples/trap.exs examples/afrobeat.exs

  `lead` plays the song under four loads and prints a row for each: the notes handed to the
  engine, how many were handed over after their beat, the shortest lead, which is the time between
  a note being handed over and its beat, the shortest lead from each part's second pass on, the
  longest call into the engine, and the longest a process handing notes over kept a normal
  scheduler of the VM without a break, in milliseconds, 0 when under one.
  The loads are `idle`, `vm_busy`, with every scheduler of the VM busy, `saves`, with the song
  loaded and laid out every 300 ms, and `os_busy`, with twice as many busy OS processes as
  schedulers.

  `saves` plays a copy of the song, saves a change to the copy at each second `--at` names, and
  prints a row for each second: the notes handed over, the late ones, the longest gap between two
  beat messages to a window, the VM's memory and its process count.
  Under the rows it prints how many times mx loaded the saves, and how long after each save its
  description reached the window.
  The song's own file is never changed.

  `buffers` renders each song a buffer of 512 frames at a time and prints, for each, the time
  filling a buffer took as a share of the time it lasts, on average and at worst, and how many
  buffers took longer than they last.

  `--seconds` is how long each measurement plays, 20 unless given.
  `--live` plays through the default output instead of an offline engine, so the song is heard,
  and adds a last column with the buffers that reached the sound card late, as the engine counts
  them; with it, `buffers` plays each song and gives the engine's own timing of the sound card's
  buffers.
  `--write FILE` writes the figures to a file, and `--compare FILE` prints each figure that is
  worse than in such a file by more than a tenth, and nothing when none is.
  The figures measured on 18 November 2026 on a MacBook Pro are in `bench/`, one file for each
  command.
  """

  use Mix.Task

  alias Mx.Bench

  @impl true
  def run(args) when is_list(args) do
    strict = [seconds: :integer, at: :string, write: :string, compare: :string, live: :boolean]
    {:ok, _apps} = Application.ensure_all_started(:mx)

    case OptionParser.parse!(args, strict: strict) do
      {opts, ["lead", path]} ->
        path |> Bench.lead(seconds(opts), live(opts)) |> report(&lead/1, opts)

      {opts, ["saves", path]} ->
        report(saves(path, opts), &saved/1, opts)

      {opts, ["buffers" | [_ | _] = paths]} ->
        paths |> Bench.buffers(seconds(opts), live(opts)) |> report(&buffers/1, opts)

      _other ->
        Mx.Command.fail(
          "usage: mix mx.bench lead|saves|buffers SONG [--seconds 20] [--at 5,10,15] [--live] [--write FILE] [--compare FILE]"
        )
    end
  end

  defp seconds(opts), do: Keyword.get(opts, :seconds, 20)
  defp live(opts), do: [live: Keyword.get(opts, :live, false)]

  defp saves(path, opts) do
    at =
      opts
      |> Keyword.get(:at, "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.to_integer/1)

    with {:ok, rows, loads, figures} <- Bench.saves(path, seconds(opts), at, live(opts)) do
      {:ok, {rows, loads}, figures}
    end
  end

  defp report({:error, message}, _print, _opts), do: Mx.Command.fail(message)

  defp report({:ok, rows, figures}, print, opts) do
    print.(rows)
    if opts[:write], do: Bench.write(opts[:write], figures)
    if opts[:compare], do: compare(opts[:compare], figures)
  end

  defp compare(path, figures) do
    case Bench.read(path) do
      {:ok, before} ->
        for {name, was, now} <- Bench.worse(before, figures) do
          IO.puts("worse: #{name} was #{was} and is #{now}")
        end

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp lead(rows) do
    keys = [
      :load,
      :calls,
      :late,
      :least_lead_ms,
      :least_later_lead_ms,
      :longest_call_ms,
      :held_ms
    ]

    header = "load,notes,late,least_lead_ms,least_later_lead_ms,longest_call_ms,held_ms"
    {keys, header} = with_late_buffers(rows, keys, header)
    IO.puts(header)
    for row <- rows, do: keys |> Enum.map_join(",", &row[&1]) |> IO.puts()
  end

  defp with_late_buffers([%{late_buffers: _} | _], keys, header) do
    {keys ++ [:late_buffers], header <> ",late_buffers"}
  end

  defp with_late_buffers(_rows, keys, header), do: {keys, header}

  defp saved({rows, loads}) do
    keys = [:second, :notes, :late, :longest_gap_ms, :memory_mb, :processes]
    header = "second,notes,late,longest_gap_ms,memory_mb,processes"
    {keys, header} = with_late_buffers(rows, keys, header)
    IO.puts(header)
    for row <- rows, do: keys |> Enum.map_join(",", &row[&1]) |> IO.puts()

    waits = Enum.join(loads.described_after_ms, ", ")
    IO.puts("loads by mx: #{loads.by_mx}; described to the window after, ms: #{waits}")
  end

  defp buffers(rows) do
    IO.puts("song,buffers,mean_percent,worst_percent,over")

    for row <- rows do
      IO.puts("#{row.song},#{row.buffers},#{row.mean_percent},#{row.worst_percent},#{row.over}")
    end
  end
end
