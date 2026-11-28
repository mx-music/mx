defmodule Mx.Measure.Strokes do
  @moduledoc """
  Measures recordings of an instrument played in strokes that run into one another, such as the
  rubs of a cuíca's stick, so a synth can play a stroke back as it was measured.

  A stroke lies between two dips of the level, each at least 7 dB deep and 40 ms from the next,
  and is kept when it comes within 22 dB of the loudest moment and lasts 40 ms or more.
  Its ends are where the level comes within 30 dB of its own loudest moment.
  The pitch is followed every 4 ms by the YIN method, between 150 and 1800 Hz, and a moment has a
  pitch when the method's doubt is 0.25 or less.
  A pitch above 480 Hz is taken an octave down when the octave under it sounds within 22 dB of it.

  The tracks of a stroke are its pitch, the level of each of its first 16 harmonics and the level
  of its noise, every 8 ms.
  They come from a least-squares fit of 20 harmonics to 14 ms of the sound every 4 ms, at the
  pitch within 3% of the one followed that fits best, averaged in pairs.
  The noise is what the fits leave of the sound, each fit weighed by its window where several
  cover a moment.
  Where the pitch moves fast the fit also leaves tone, so the noise is kept 15 dB or more under
  the moment's level and the rest is given back to the harmonics.
  The pitch is given in cents against the note the stroke settles at, the pitch that half of its
  energy lies under.
  The levels are in dB under the stroke's loudest step, and a level more than 66 dB down is given
  as -127, for silence.
  """

  alias Mx.Engine.Mxs.Native
  alias Mx.Signal

  @hop 0.004
  @step 2

  @doc "The seconds between two steps of a stroke's tracks."
  def step, do: @hop * @step

  @doc """
  Finds the strokes of a recording and follows its pitch, and returns `{:ok, recording}` for
  `tracks/3`, or `{:error, message}` naming the file.
  """
  def file(path) when is_binary(path) do
    with {:ok, %{strokes: found} = recording} <- Signal.measure_data(path, "strokes", &found/3) do
      if found == [], do: {:error, "found no strokes in #{path}"}, else: {:ok, recording}
    end
  end

  @doc """
  Finds the strokes of a sound and follows its pitch.

  Each stroke has the seconds it lasts `from` and `to`, its `level` in dB under the loudest
  moment, the `note` its second half holds, and `start`, the cents its first moments lie from that
  note.
  """
  def strokes(samples, rate) when is_list(samples) and is_integer(rate) do
    {data, format} = Signal.packed(samples)
    found(data, format, rate / 1)
  end

  @doc """
  The tracks of the stroke at `index` of a recording's strokes, or nil when the stroke has no
  pitch.

  `alone: true` carries on past the stroke into the ring it leaves, up to 0.25 seconds, the next
  stroke, or 56 dB under the stroke's loudest moment, with no noise.
  `ignore: {low, high}` leaves out the harmonics between two frequencies, for a steady tone in the
  recording that is not the instrument's.

  It gives the `note`, the `cents` of each step, the `levels` of each step as 16 harmonics and
  then the noise, `body`, the steps that are the stroke and not its ring, and `scoop`, the
  semitones the stroke starts under its note.
  """
  def tracks(%{strokes: strokes, native: native}, index, opts \\ [])
      when is_integer(index) and index >= 0 and is_list(opts) do
    _stroke = Enum.fetch!(strokes, index)
    ignore = with {low, high} <- Keyword.get(opts, :ignore), do: {low / 1, high / 1}
    Native.stroke_tracks(native, index, Keyword.get(opts, :alone, false), ignore)
  end

  defp found(data, format, rate) do
    {native, strokes} = Native.measure_strokes(data, format, rate)
    %{native: native, strokes: strokes}
  end
end
