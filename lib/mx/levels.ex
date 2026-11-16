defmodule Mx.Levels do
  @moduledoc """
  A recording's levels over time as numbers, for a picture that reacts to what was played: how loud each part of the sound is at each moment, how bright it is, and where each stroke lands.

  The levels are worked out by `Mx.Engine.Mxs.Native`, from the recording's data as it is in the file, from every recording `mix mx.spectrogram` reads.
  """

  alias Mx.Audio
  alias Mx.Engine.Mxs.Native

  @bands for octave <- 0..9, do: {20 * 2 ** octave, 20 * 2 ** (octave + 1)}

  @doc "The octaves the bands of a row cover, as `{low, high}` in Hz, from 20 Hz to 20,480 Hz, as the spectrogram's side is divided."
  def bands, do: @bands

  @doc """
  The rows of the recording at `path`, as `{:ok, rows}` or `{:error, "cannot read PATH"}`.

  There are `per_second:` rows a second, 30 unless given, and each covers all the sound from its moment to the next's, so no stroke falls between two rows.
  A row has the second it starts at as `at`, the level of the whole sound as `level` and of each octave of `bands/0` as `bands`, all in dB under the recording's loudest row, down to -100, and as `brightness` the frequency in Hz that half its energy lies under.
  """
  def rows(path, opts \\ []) when is_binary(path) and is_list(opts) do
    per_second = Keyword.get(opts, :per_second, 30)

    with {:ok, %{rate: rate} = format, data} <- Audio.raw(path) do
      rows =
        for {at, level, bands, brightness} <-
              Native.level_rows(data, native_format(format), rate / 1, per_second / 1) do
          %{at: at, level: level, bands: bands, brightness: brightness}
        end

      {:ok, rows}
    end
  end

  @doc """
  The strokes of the recording at `path`, as `{:ok, strokes}` or `{:error, "cannot read PATH"}`.

  A stroke is where the sound's octaves rise sharply together, at least 50 ms after the stroke before it, so a key struck again while it still rings is a stroke of its own.
  Each has the second it starts at as `at` and its level as `level`, in dB under the loudest stroke's.
  """
  def strokes(path) when is_binary(path) do
    with {:ok, %{rate: rate} = format, data} <- Audio.raw(path) do
      strokes =
        for {at, level} <- Native.strokes(data, native_format(format), rate / 1) do
          %{at: at, level: level}
        end

      {:ok, strokes}
    end
  end

  defp native_format(%{kind: kind, bits: bits, channels: channels}) do
    {Atom.to_string(kind), bits, channels}
  end
end
