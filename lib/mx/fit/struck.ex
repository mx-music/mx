defmodule Mx.Fit.Struck do
  @moduledoc """
  Fits a synth of struck notes to recordings partial by partial, and checks it against them.

  The recordings are a folder of single notes named as NSynth names them, ending in the MIDI note and velocity, such as `keyboard_electronic_098-064-025.wav`.
  Each is measured as `Mx.Measure.partials/2` describes, over its first 2.9 seconds.
  Fitting renders each note's partials as sines, measures the render the same way, and corrects each partial's level at 27 times after the strike until the render matches the recording, then fits the strike's noise in each band one ERB wide from 50 Hz to 8 kHz to what the recording holds beyond the sines.
  The figures keep every partial of every recording, for mxs to play: a note or velocity that was not recorded takes its figures from the recordings nearest it.

  Checking renders the synth at each recording's note and velocity and compares the two in the same way, each brought to the same total over its first half second:
  partial by partial, the gap over the first 20 ms and the mean gap over the note while either stands 10 dB above the recording's noise floor;
  and in ERB bands, the mean gap over the note while either stands clear of the floor.
  """

  alias Mx.{Audio, Measure, Signal}
  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  @seconds 3.2

  @doc "The recordings in a folder, as `{path, note, velocity}` in order of note and velocity, those between `low` and `high` when given."
  def recordings(folder, notes \\ nil) when is_binary(folder) do
    case File.ls(folder) do
      {:ok, names} ->
        found =
          for name <- Enum.sort(names),
              [note, velocity] <- [
                Regex.run(~r/-(\d+)-(\d+)\.(wav|aiff?)$/i, name, capture: [1, 2])
              ],
              note = String.to_integer(note),
              notes == nil or note in notes,
              do: {Path.join(folder, name), note, String.to_integer(velocity)}

        if found == [],
          do: {:error, "found no recordings named like name-064-025.wav in #{folder}"},
          else: {:ok, Enum.sort_by(found, &{elem(&1, 1), elem(&1, 2)})}

      {:error, reason} ->
        reason = :file.format_error(reason)
        {:error, "cannot read #{folder}: #{reason}"}
    end
  end

  @doc "The figures fitted to the recordings, as mxs reads them."
  def figures(recordings) when is_list(recordings) do
    recordings
    |> Enum.map(fn {path, note, velocity} ->
      {:ok, %{rate: rate} = format, data} = Audio.raw(path)
      {data, Signal.native(format), rate / 1, note, velocity}
    end)
    |> Native.fit_struck()
  end

  @doc """
  Renders `synth` at each recording's note and velocity and compares it with the recording.
  Returns one check a recording, with its `note`, `velocity`, `erb` gap and `partials`, each partial with its `ratio`, `harmonic`, `below` the loudest in dB, `strike` gap and `mean` gap.
  """
  def check(synth, recordings) when is_list(recordings) do
    recordings
    |> Task.async_stream(
      fn {path, note, velocity} ->
        {:ok, %{rate: rate} = format, data} = Audio.raw(path)
        sound = Mxs.render_note(synth, [note: note, vel: velocity / 127], @seconds, nil, [])
        {rendered, packing} = Signal.packed(sound)
        recording = {data, Signal.native(format), rate / 1}

        check =
          Native.check_struck(recording, {rendered, packing, Mxs.render_rate() / 1}, note / 1)

        Map.merge(check, %{note: note, velocity: velocity})
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, check} -> check end)
  end

  @doc """
  The checks summed up: the partials within 30 dB of each note's loudest, `strong`, and those 30 to 60 dB down, `weaker`, each as a count and the share within 2 dB over the first 20 ms (`strike`), within 2 dB on average for the strong (`mean`), or within 4 dB on average for the weaker; and the ERB gap at the median note and the worst.
  """
  def summary(checks) when is_list(checks) do
    partials = Enum.flat_map(checks, & &1.partials)
    strong = Enum.filter(partials, &(&1.below <= 30))
    weaker = Enum.filter(partials, &(&1.below > 30 and &1.below <= 60))
    erbs = checks |> Enum.map(& &1.erb) |> Enum.sort()

    %{
      strong: %{
        count: length(strong),
        strike: share(strong, &(abs(&1.strike) <= 2)),
        mean: share(strong, &(&1.mean <= 2))
      },
      weaker: %{count: length(weaker), mean: share(weaker, &(&1.mean <= 4))},
      erb: %{median: Enum.at(erbs, div(length(erbs), 2)), worst: List.last(erbs)}
    }
  end

  @doc "The `count` partials within 60 dB of their note's loudest furthest off on average, each with its note and velocity, furthest first."
  def furthest_partials(checks, count) do
    checks
    |> Enum.flat_map(fn check ->
      for partial <- check.partials,
          partial.below <= 60,
          do: Map.merge(partial, Map.take(check, [:note, :velocity]))
    end)
    |> Enum.sort_by(& &1.mean, :desc)
    |> Enum.take(count)
  end

  @doc "The `count` notes furthest off in ERB bands, furthest first."
  def furthest_notes(checks, count),
    do: checks |> Enum.sort_by(& &1.erb, :desc) |> Enum.take(count)

  @doc "A recording's note and velocity as the check prints them, such as `e4 vel 25`."
  def label(%{note: note, velocity: velocity}) do
    name = Measure.name(note)
    "#{name} vel #{velocity}"
  end

  defp share([], _keep), do: nil
  defp share(partials, keep), do: Enum.count(partials, keep) / length(partials)
end
