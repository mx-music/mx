defmodule Mx.Fit.Held do
  @moduledoc """
  Fits a synth of held notes, bowed, blown or played on an organ, to recordings partial by partial, and checks it against them.

  The recordings are a list, as `Mx.Fit.Struck` takes it: one line a file, with the notes it holds, the velocity it was played at from 1 to 127, `kept` when the recordings keep their levels from one velocity to the next, and the file.
  A run is split into its notes where each comes out of the quiet between them, since a held note swells rather than strikes, and a stretch that is not one of its notes, such as a breath or a key's click, is named and left out.
  Each line names every note its file holds, since a stretch is named among them, and a note two lines give at one velocity is taken from the first, as one string is chosen over another.

  Each note's pitch is followed every 5 ms, and the note resampled along it to one steady pitch, so its vibrato and drift do not smear its partials.
  Its harmonics are then followed every 2.5 ms as a struck note's partials are: through the attack, where the note holds, within 3 dB of its held level, and once the player lets it go.
  Fitting gives each harmonic its level at the struck notes' times until the recording lets the note go, held at the last after that so a longer note holds as the recording last did, and its slope once let go; the noise between the harmonics the same, in each band one ERB wide, from the median of each stretch so a burst does not lift it; and the vibrato's rate and depth, with how far each harmonic's level swings with it.
  The levels and slopes are corrected against renders of the figures, measured the same way, until they match the recording.

  Checking renders the synth at each recording's note and velocity, held as long as the recording holds, measures it the same way, and brings it to the recording's total where the recording holds:
  partial by partial, the mean gap over the attack and over the held part while either stands 10 dB above the floor; and in ERB bands, the mean gap from the start until a second after the note is let go while either stands clear of the floor.
  """

  alias Mx.Fit.Struck
  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native
  alias Mx.Signal

  @doc "The recordings a list gives, as `Mx.Fit.Struck.listed/3` gives them, split into held notes, each note and velocity from the first line that gives it."
  def listed(list, notes \\ nil) do
    with {:ok, recordings, lines} <- Struck.listed(list, notes, held: true) do
      order = lines |> Enum.with_index() |> Map.new(fn {line, index} -> {line.path, index} end)

      firsts =
        recordings
        |> Enum.sort_by(&{&1.note, &1.velocity, order[&1.path]})
        |> Enum.uniq_by(&{&1.note, &1.velocity})

      {:ok, firsts, lines}
    end
  end

  @doc "The figures fitted to the recordings, as mxs reads them."
  def figures(recordings) when is_list(recordings),
    do: recordings |> Struck.native() |> Native.fit_held()

  @doc "Each recording measured partial by partial: its pitch, where it holds from and is let go, its fall after, its vibrato, and each partial's levels."
  def measure(recordings) when is_list(recordings) do
    recordings
    |> Struck.native()
    |> Task.async_stream(&Native.measure_held_partials/1, timeout: :infinity)
    |> Enum.zip_with(recordings, fn {:ok, measured}, recording ->
      Map.merge(measured, Map.take(recording, [:note, :velocity, :path]))
    end)
  end

  @doc """
  Renders `synth` at each recording's note and velocity, held as long as the recording holds, with `options`, and compares it with the recording.
  Returns one check a recording, as `Mx.Fit.Struck.check/3` does, its `strike` gap the attack's.
  """
  def check(synth, recordings, options \\ []) when is_list(recordings) do
    recordings
    |> Task.async_stream(
      fn recording ->
        [native] = Struck.native([recording])
        rendered = render(synth, recording, native, options)
        check = Native.check_held(native, rendered)
        Map.merge(check, Map.take(recording, [:note, :velocity, :kept]))
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, check} -> check end)
  end

  @doc "Checks the fit's own render of each recording against it, as `check/3` checks a synth: the figures fitted to the recording played as sines and noise with their vibrato, with no synth."
  def own(recordings) when is_list(recordings) do
    recordings
    |> Struck.native()
    |> Task.async_stream(&Native.check_fit_held/1, timeout: :infinity)
    |> Enum.zip_with(recordings, fn {:ok, check}, recording ->
      Map.merge(check, Map.take(recording, [:note, :velocity, :kept]))
    end)
  end

  @doc "A tour for listening of `count` recordings spread over the notes and velocities, each followed by `synth` held as long, as `{samples, rate}`."
  def tour(synth, recordings, count, options \\ []) when is_list(recordings) and count > 0 do
    picked = Struck.spread(recordings, count)

    pairs =
      picked
      |> Struck.native()
      |> Enum.zip(picked)
      |> Task.async_stream(fn {native, recording} -> {native, render(synth, recording, native, options)} end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, pair} -> pair end)

    {Native.tour_struck(pairs), Mxs.render_rate()}
  end

  defp render(synth, recording, native, options) do
    {_held, release, _start} = Native.timing_held(native)
    seconds = recording.seconds + 0.3
    vel = recording.velocity / 127
    params = [note: recording.note, vel: vel, sustain: release] ++ options
    sound = Mxs.render_note(synth, params, seconds, nil, [])
    {rendered, packing} = Signal.packed(sound)
    {rendered, packing, Mxs.render_rate() / 1}
  end
end
