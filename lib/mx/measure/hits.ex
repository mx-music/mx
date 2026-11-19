defmodule Mx.Measure.Hits do
  @moduledoc """
  Measures recordings of hits, struck bars, bells, drums and scrapers, with or without a pitch, so a synth's design can be compared with a real instrument's.

  A file holds one hit or several, one after another, each starting from silence.
  Several hits given a note are a run from that note up to 11 semitones above it, split into its notes as `Mx.Fit.Struck` splits a run, so a bar that rings on under the next one is not a hit of its own; each hit gives its note, the run's or the one given.
  Rumble is filtered out below three quarters of the note given, or below 30 Hz without one, and the bands are measured from there up.
  For each hit it finds the level of each band as the hit starts, against the loudest band, and the seconds each band takes to fade 60 dB.
  It also lists the frequencies of the hit's strongest peaks, up to six within 30 dB of the loudest, as ratios to the lowest of them, so the partials of a bar or a drum show whatever their pitch.
  It also gives each band's level at 0, 50, 100 and 200 ms after the hit's loudest moment, against the loudest band then, nil past the hit's end and -40 for a level more than 40 dB down, and the second the hit starts at in the sound.
  With `partials:` a count, it also lists up to that many of the strongest partials within 40 dB of the loudest, lowest first, each with its frequency in Hz, its ratio to the lowest, its level in dB against the loudest and the seconds it takes to fade 60 dB, or nil when it does not fade; two partials closer than 1% are one.
  """

  alias Mx.Engine.Mxs.Native
  alias Mx.Signal

  @moments [0, 50, 100, 200]

  @doc "Measures each hit of a recording, with the note it plays or nil, and returns `{:ok, hits}` or `{:error, message}` naming the file."
  def file(path, note, opts \\ [])
      when is_binary(path) and (is_integer(note) or is_nil(note)) and is_list(opts) do
    Signal.measure_data(
      path,
      "hits",
      &Native.measure_hits(&1, &2, &3, note, opts[:partials], false)
    )
  end

  @doc "Measures each hit of a sound, one after another from silence, with the note they play or nil."
  def hits(samples, rate, note, opts \\ [])
      when is_list(samples) and is_integer(rate) and (is_integer(note) or is_nil(note)) and
             is_list(opts) do
    {data, format} = Signal.packed(samples)
    Native.measure_hits(data, format, rate / 1, note, opts[:partials], false)
  end

  @doc "Measures a sound that is one hit from its first sample, such as a synth rendered offline, or returns nil when it is too short."
  def hit(samples, rate, note, opts \\ [])
      when is_list(samples) and is_integer(rate) and (is_integer(note) or is_nil(note)) and
             is_list(opts) do
    {data, format} = Signal.packed(samples)
    data |> Native.measure_hits(format, rate / 1, note, opts[:partials], true) |> List.first()
  end

  @doc "The milliseconds after a hit's loudest moment that `moments` are taken at."
  def moment_times, do: @moments

  @doc "The median level of each band at each moment over the hits, leaving out hits that end before it, or nil when none reaches it."
  def moments(hits) when is_list(hits) do
    found = Enum.flat_map(hits, & &1.moments)

    for band <- Signal.bands(),
        inside = Enum.filter(found, &(&1.band == band)),
        inside != [] do
      levels =
        inside
        |> Enum.map(& &1.levels)
        |> Enum.zip_with(fn levels ->
          case Enum.reject(levels, &is_nil/1) do
            [] -> nil
            reached -> Signal.median(reached)
          end
        end)

      %{band: band, levels: levels}
    end
  end

  @doc "The median level and fade of each band over the hits."
  def summary(hits) when is_list(hits) do
    found = Enum.flat_map(hits, & &1.bands)

    for band <- Signal.bands(),
        inside = Enum.filter(found, &(&1.band == band)),
        inside != [] do
      fades = for %{fade: fade} <- inside, fade != nil, do: fade
      fade = if fades == [], do: nil, else: Signal.median(fades)

      %{
        band: band,
        level: Signal.median(Enum.map(inside, & &1.level)),
        fade: fade,
        count: length(inside)
      }
    end
  end
end
