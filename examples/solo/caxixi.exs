defmodule Caxixi do
  @moduledoc """
  A piece for the caxixi alone written for mx: its part in two of capoeira's toques, shaken with
  each of the berimbau's strokes.
  In angola the berimbau buzzes twice and then plays its open note, and the caxixi leans on the
  open note; in são bento grande the strokes run on, and the caxixi leans on the first buzz of
  each pair and on the open note that closes the phrase.
  """

  use Mx.Song, tempo: 100

  # Two beats of angola as {beat, stroke}: two buzzes, then the open note.
  @angola [{0, :buzz}, {0.5, :buzz}, {1, :open}]

  # Four beats of são bento grande: buzz, buzz, open, closed, then buzz, buzz, closed, open.
  @sao_bento_grande [
    {0, :buzz},
    {0.5, :buzz},
    {1, :open},
    {1.5, :closed},
    {2, :buzz},
    {2.5, :buzz},
    {3, :closed},
    {3.5, :open}
  ]

  part :caxixi, synth: :caxixi

  def song, do: repeat(form([angola: 2, sao_bento_grande: 2], &part(:caxixi, caxixi(&1))))

  defp caxixi(:angola) do
    strokes =
      for cycle <- 0..7, {beat, stroke} <- @angola do
        {2 * cycle + beat, hit(vel: if(stroke == :open, do: 0.85, else: 0.5))}
      end

    at(strokes, 16)
  end

  defp caxixi(:sao_bento_grande) do
    strokes =
      for cycle <- 0..3, {beat, _stroke} <- @sao_bento_grande do
        accented = beat in [0, 2, 3.5]
        {4 * cycle + beat, hit(vel: if(accented, do: 0.8, else: 0.45))}
      end

    at(strokes, 16)
  end
end
