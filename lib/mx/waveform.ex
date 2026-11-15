defmodule Mx.Waveform do
  @moduledoc """
  Draws a recording's waveform into a PNG image: a row of bars on a dark background, one for each slice of the recording.

  The bars are 2 pixels wide and 1 pixel apart, with rounded ends, and stand 40 pixels in from each side.
  A bar is as tall as its slice is loud, against the loudest slice: the level is the slice's RMS, raised to the power 0.8 so that quiet passages stay visible, and a silent slice is a dot.
  The image is 1500 pixels wide and 150 high unless `width:` and `height:` give another size.
  The bars are grey, or amber with `colour: :amber`, the two colours `Mx.Video` shows before and after its playhead.
  """

  alias Mx.{Audio, PNG}
  alias Mx.Engine.Mxs.Native

  @width 1500
  @height 150
  @margin 40
  @edge 12
  @bar 2
  @gap 1
  @fine 4
  @background {17, 19, 24}
  @colours %{grey: {74, 80, 96}, amber: {242, 184, 75}}

  @doc "Writes the waveform of the recording at `path` to the PNG file `out`, and returns `:ok`, or `{:error, \"cannot read PATH\"}`."
  def write(path, out, opts \\ []) when is_binary(path) and is_binary(out) and is_list(opts) do
    with {:ok, %{channels: channels, bits: bits, kind: kind}, data} <- Audio.raw(path) do
      width = Keyword.get(opts, :width, @width)
      height = Keyword.get(opts, :height, @height)
      colour = Map.fetch!(@colours, Keyword.get(opts, :colour, :grey))
      count = max(div(width - 2 * @margin + @gap, @bar + @gap), 1)
      {_peak, levels} = Native.levels(data, {Atom.to_string(kind), bits, channels}, count)
      File.write!(out, PNG.encode(width, height, rows(levels, width, height, colour)))
    end
  end

  @doc "The pixels across at which the bars of an image of a width start and end."
  def span(width \\ @width) when is_integer(width) do
    count = max(div(width - 2 * @margin + @gap, @bar + @gap), 1)
    {@margin, @margin + count * (@bar + @gap) - @gap}
  end

  defp rows(levels, width, height, colour) do
    loudest = Enum.max(levels)
    loudest = if loudest > 0, do: loudest, else: 1.0
    radius = @bar / 2
    tallest = max(height / 2 - @edge, radius)

    halves =
      for {level, index} <- Enum.with_index(levels),
          left = @margin + index * (@bar + @gap),
          half = max(radius, (level / loudest) ** 0.8 * tallest),
          across <- 0..(@bar - 1),
          into: %{},
          do: {left + across, {left + radius, half}}

    for top <- 0..(height - 1), into: <<>> do
      for left <- 0..(width - 1), into: <<>> do
        halves |> Map.get(left) |> covered(left, top, height / 2, radius) |> pixel(colour)
      end
    end
    |> then(&for <<row::binary-size(^width * 3) <- &1>>, do: row)
  end

  # The share of a pixel inside a bar, from 16 points in it.
  defp covered(nil, _left, _top, _middle, _radius), do: 0.0

  defp covered({_centre, half}, _left, top, middle, _radius)
       when abs(top + 0.5 - middle) > half + 1,
       do: 0.0

  defp covered({centre, half}, left, top, middle, radius) do
    inside =
      for down <- 0..(@fine - 1),
          across <- 0..(@fine - 1),
          aside = left + (across + 0.5) / @fine - centre,
          beyond = max(abs(top + (down + 0.5) / @fine - middle) - (half - radius), 0.0),
          aside * aside + beyond * beyond <= radius * radius,
          reduce: 0,
          do: (count -> count + 1)

    inside / (@fine * @fine)
  end

  defp pixel(share, {red, green, blue}) do
    {back_red, back_green, back_blue} = @background

    <<round(back_red + (red - back_red) * share),
      round(back_green + (green - back_green) * share),
      round(back_blue + (blue - back_blue) * share)>>
  end
end
