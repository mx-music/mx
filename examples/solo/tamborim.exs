defmodule Tamborim do
  @moduledoc """
  A piece for the tamborim alone written for mx: its parts in a samba batucada, in 2/4, two beats
  to the bar.
  The teleco-teco is a two-bar figure of sixteenths struck off the beat; the carreteiro strikes
  every sixteenth with the figure's strokes accented; a virada closes each phrase with a run of
  thirty-second strokes that swells into an accent.
  """

  use Mx.Song, tempo: 100

  @note 72.03

  # The teleco-teco's two bars, in sixteenths.
  @teleco_teco [0, 2, 5, 7, 9, 11, 14]

  part :tamborim, synth: :tamborim

  def song do
    repeat(form())
  end

  defp form do
    seq([
      part(:tamborim, teleco_teco()),
      part(:tamborim, carreteiro()),
      part(:tamborim, virada()),
      part(:tamborim, carreteiro())
    ])
  end

  defp teleco_teco do
    strokes =
      for repeat <- 0..3, sixteenth <- @teleco_teco do
        {4 * repeat + sixteenth / 4,
         hit(note: @note, vel: if(sixteenth == 0, do: 0.85, else: 0.7))}
      end

    at(strokes, 16)
  end

  # Every sixteenth, the teleco-teco's strokes accented and the rest soft.
  defp carreteiro do
    strokes =
      for repeat <- 0..3, sixteenth <- 0..15 do
        vel = if sixteenth in @teleco_teco, do: 0.8, else: 0.4
        {4 * repeat + sixteenth / 4, hit(note: @note, vel: vel)}
      end

    at(strokes, 16)
  end

  # Three repeats of the teleco-teco, then a bar of thirty-seconds that swells into an accent on
  # the next downbeat.
  defp virada do
    figure =
      for repeat <- 0..2, sixteenth <- @teleco_teco do
        {4 * repeat + sixteenth / 4, hit(note: @note, vel: 0.7)}
      end

    run =
      for step <- 0..15 do
        {14 + step / 8, hit(note: @note, vel: Float.round(0.3 + 0.03 * step, 2))}
      end

    at(figure ++ run, 16)
  end
end
