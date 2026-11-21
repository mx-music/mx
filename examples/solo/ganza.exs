defmodule Ganza do
  @moduledoc """
  A beat is a quarter note of samba's 2/4, so a pass is two bars of sixteenths.
  """

  use Mx.Song, tempo: 100

  part :ganza, synth: :ganza
  part :shaker, synth: :shaker

  def song do
    repeat(form())
  end

  # The form, each of its passes a section.
  defp form do
    form([one: 4, two: 2, three: 2, four: 4], fn section, %{pass: pass} ->
      together([
        part(:ganza, ganza(section, pass)),
        part(:shaker, shaker(section, pass))
      ])
    end)
  end

  # A pass of ganza, as 4 beats.
  defp ganza(section, _pass) do
    hits = for {beat, up, vel} <- strokes(section), do: {beat, hit(up: up, vel: vel)}
    at(hits, 4)
  end

  # A pass of the shaker, as 4 beats: silent in the first section, then down on the beats and up
  # between them.
  defp shaker(section, _pass) do
    if section == :one do
      rest(4)
    else
      downs = for beat <- [0, 1, 2, 3], do: {beat, hit(vel: 0.5)}
      ups = for beat <- [0.5, 1.5, 2.5, 3.5], do: {beat, hit(up: 1, vel: 0.35)}
      at(downs ++ ups, 4)
    end
  end

  # Each stroke as {beat, up, vel}; the accent on each beat's first sixteenth is mx's own, since
  # the patterns mark none.
  defp strokes(section) do
    steps = section |> pattern() |> String.replace(" ", "") |> String.graphemes()

    for {stroke, step} <- Enum.with_index(steps), stroke != "O" do
      vel = if rem(step, 4) == 0, do: 0.85, else: 0.45
      {step * 0.25, if(stroke == "B", do: 1, else: 0), vel}
    end
  end

  # Four samba ganzá patterns from
  # https://kkfsamba2014.wordpress.com/2014/10/01/samba-patterns-for-ganza/, a sixteenth each:
  # F pushes the ganzá forward for a down stroke, B pulls it back for an up stroke, and O rests.
  defp pattern(:one), do: "FBFB FBFB FBFB FBFB"
  defp pattern(:two), do: "FOBO FOBO FOBO FOBO"
  defp pattern(:three), do: "FOOB FOOB FOOB FOOB"
  defp pattern(:four), do: "FBOF BFOB FBOF BFOB"
end
