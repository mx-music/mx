defmodule Mx.Fit do
  @moduledoc """
  Searches for the values of a synth's controls that bring its held notes closest to recordings of them, as `mix mx.fit` does.

  The recordings come in dynamics, each a vel and the files played at it, and each dynamic is measured as `Mx.Measure.Held` measures held notes.
  Notes found below the lowest note given are spurious onsets, and stretches whose fundamental stands more than 25 dB below the median fundamental of their dynamic are breaths or key clicks between notes, so both are left out.
  The synth renders at every semitone from the lowest note given to the highest found, at each dynamic's vel, without vibrato, held as long as the recordings' notes at that dynamic hold, the median of those kept.
  A setting scores how far each band's harmonics and the noise between them, from the lowest frequency given up to 4 kHz, fall more than 4 dB from the recordings', and how far the attack falls more than 20 percent from theirs, at each dynamic.
  The search tries each control a step up and a step down, keeps whichever lowers the score, and goes through the controls three times.
  """

  alias Mx.Engine.Mxs
  alias Mx.Measure.Held
  alias Mx.{Signal, Synths}

  @quiet 25
  @top 4000
  @slack 4
  @attack_slack :math.log(1.2)
  @attack_weight 20
  @rounds 3
  @version :drone

  @doc """
  Measures each `{vel, [{path, note}]}` dynamic, and returns `{:ok, dynamics, cached?}` or `{:error, message}` naming the file.

  Each dynamic has its vel, attack and band levels, and how many notes it kept, found below the lowest note, and found too quiet.
  With `drone` true, each file is measured as one note held from its first sample to its last, and the attack is nil, since a drone's recording starts wherever it was cut.
  The figures are kept in the system's temporary folder and reused until a file changes.
  """
  def recordings(dynamics, drone \\ false) when is_list(dynamics) and is_boolean(drone) do
    case cached(dynamics, drone) do
      {:ok, measured} -> {:ok, measured, true}
      :none -> measure(dynamics, drone)
    end
  end

  @doc "The lowest note of the files given."
  def lowest(dynamics) do
    dynamics |> Enum.flat_map(&elem(&1, 1)) |> Enum.map(&elem(&1, 1)) |> Enum.min()
  end

  @doc """
  Each dynamic's attack ratio less one, or nil when the recordings have no attack, and for each band the level of its harmonics, then of its noise, in the recordings and the difference in dB, the synth's against the recordings', with the given controls.
  A band is left out of either list where the recordings or the synth have no figure for it.
  """
  def misses(synth, recorded, notes, from, controls) do
    for dynamic <- recorded do
      rendered = Held.summary(render(synth, notes, dynamic, controls))
      levels = Map.new(rendered.bands, &{&1.band, &1.level})
      noises = Map.new(rendered.bands, &{&1.band, &1.noise})

      %{
        vel: dynamic.vel,
        attack: dynamic.attack && rendered.attack / dynamic.attack - 1,
        bands: differences(dynamic.bands, levels, from),
        noise: differences(dynamic.noise, noises, from)
      }
    end
  end

  defp differences(recorded, rendered, from) do
    for {{low, _high} = band, level} <- Enum.sort(recorded),
        level != nil,
        low >= from and low < @top,
        other = rendered[band],
        do: {band, level, other - level}
  end

  @doc "The score of misses: 0 when every band's harmonics and noise are within 4 dB and every attack within 20 percent."
  def score(misses) do
    Enum.sum(
      for %{attack: attack, bands: bands, noise: noise} <- misses do
        attack(attack) +
          Enum.sum(
            for {_band, _level, difference} <- bands ++ noise,
                do: max(abs(difference) - @slack, 0)
          )
      end
    )
  end

  defp attack(nil), do: 0
  defp attack(attack), do: max(abs(:math.log(1 + attack)) - @attack_slack, 0) * @attack_weight

  @doc """
  Searches from the controls' starting values, each a map of name, value, step and whether the step is a ratio.

  `report` is called with `{:start, score}`, `{:round, number}` and `{:kept, name, value, score}`, and the best values and their score are returned.
  """
  def search(synth, recorded, notes, from, controls, report) do
    score_of = fn values -> score(misses(synth, recorded, notes, from, values)) end
    values = for control <- controls, do: {control.name, control.value}
    start = score_of.(values)
    report.({:start, start})

    Enum.reduce(1..@rounds, {values, start}, fn round, best ->
      report.({:round, round})

      Enum.reduce(controls, best, fn control, {values, current} ->
        {tried, score} =
          for direction <- [1, -1] do
            tried =
              Keyword.put(values, control.name, step(values[control.name], control, direction))

            {tried, score_of.(tried)}
          end
          |> Enum.min_by(&elem(&1, 1))

        if score < current do
          report.({:kept, control.name, tried[control.name], score})
          {tried, score}
        else
          {values, current}
        end
      end)
    end)
  end

  @doc "A value moved a step up, direction 1, or down, -1."
  def step(value, %{step: step, ratio: true}, direction), do: value * step ** direction
  def step(value, %{step: step}, direction), do: value + step * direction

  defp render(synth, notes, %{vel: vel, held: held}, controls) do
    dir = Path.join(System.tmp_dir!(), "mx-fit-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      notes
      |> Task.async_stream(
        fn note ->
          given = [note: note, vel: vel, vibrato: 0, sustain: held]
          opts = for {key, value} <- given, Synths.option?(synth, key), do: {key, value}

          Held.note(
            Mxs.render_note(synth, opts ++ controls, held + 0.5, dir, []),
            Mxs.render_rate(),
            note
          )
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, note} -> List.wrap(note) end)
    after
      File.rm_rf!(dir)
    end
  end

  defp measure(dynamics, drone) do
    lowest = lowest(dynamics)

    found =
      Enum.reduce_while(dynamics, [], fn {vel, files}, done ->
        case measure_files(files, drone) do
          {:ok, notes} -> {:cont, [dynamic(vel, notes, lowest, drone) | done]}
          {:error, message} -> {:halt, {:error, message}}
        end
      end)

    case found do
      {:error, message} ->
        {:error, message}

      found ->
        measured = Enum.reverse(found)
        File.mkdir_p!(Path.dirname(cache_path(dynamics, drone)))
        File.write!(cache_path(dynamics, drone), :erlang.term_to_binary(measured))
        {:ok, measured, false}
    end
  end

  defp measure_files(files, drone) do
    measure = if drone, do: &Held.drone/2, else: &Held.file/2

    files
    |> Task.async_stream(fn {path, note} -> measure.(path, note) end, timeout: :infinity)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, notes}}, {:ok, all} -> {:cont, {:ok, all ++ notes}}
      {:ok, {:error, message}}, _all -> {:halt, {:error, message}}
    end)
  end

  defp dynamic(vel, notes, lowest, drone) do
    {below, kept} = Enum.split_with(notes, &(&1.note < lowest))
    middle = Signal.median(for %{harmonics: [first | _]} <- kept, do: first.level)
    {quiet, kept} = Enum.split_with(kept, &quiet?(&1, middle - @quiet))
    summary = Held.summary(kept)

    %{
      vel: vel,
      attack: if(drone, do: nil, else: summary.attack),
      held: Signal.median(Enum.map(kept, & &1.held)),
      bands: Map.new(summary.bands, &{&1.band, &1.level}),
      noise: Map.new(summary.bands, &{&1.band, &1.noise}),
      notes: length(kept),
      highest: kept |> Enum.map(& &1.note) |> Enum.max(),
      below: length(below),
      quiet: length(quiet)
    }
  end

  defp quiet?(%{harmonics: [first | _]}, floor), do: first.level < floor
  defp quiet?(_note, _floor), do: false

  defp cached(dynamics, drone) do
    case File.read(cache_path(dynamics, drone)) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary)}
      {:error, _reason} -> :none
    end
  end

  # The figures are named after their version, whether they measure drones, the files, their notes
  # and vels, and each file's size and time of change.
  defp cache_path(dynamics, drone) do
    key =
      for {vel, files} <- [{{@version, drone}, []} | dynamics] do
        {vel, Enum.map(files, fn {path, note} -> {Path.expand(path), note, stamp(path)} end)}
      end

    Path.join([System.tmp_dir!(), "mx-fit", "#{:erlang.phash2(key, 4_294_967_296)}.term"])
  end

  @doc "A file's size and time of change, which name what was fitted to it, or nil when it cannot be read."
  def stamp(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{size: size, mtime: mtime}} -> {size, mtime}
      {:error, _reason} -> nil
    end
  end
end
