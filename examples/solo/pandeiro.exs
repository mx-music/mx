defmodule Pandeiro do
  @moduledoc """
  A beat is a quarter note of 2/4, so a pass is two bars of sixteenths.
  """

  use Mx.Song, tempo: 100

  part :pandeiro_thumb, synth: :pandeiro_thumb
  part :pandeiro_heel, synth: :pandeiro_heel
  part :pandeiro_jingles, synth: :pandeiro_jingles
  part :pandeiro_slap, synth: :pandeiro_slap

  def song do
    repeat(form())
  end

  # The form, each of its passes a section.
  defp form do
    form([choro: 4, samba_de_roda: 2, baiao: 2, forro: 2, coco: 4], fn section, %{pass: pass} ->
      together([
        part(:pandeiro_thumb, pandeiro_thumb(section, pass)),
        part(:pandeiro_heel, pandeiro_heel(section, pass)),
        part(:pandeiro_jingles, pandeiro_jingles(section, pass)),
        part(:pandeiro_slap, pandeiro_slap(section, pass))
      ])
    end)
  end

  # A pass of pandeiro_thumb, as 4 beats.
  defp pandeiro_thumb(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["o", "ox"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_heel, as 4 beats.
  defp pandeiro_heel(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["h"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_jingles, as 4 beats.
  defp pandeiro_jingles(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["f"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # A pass of pandeiro_slap, as 4 beats.
  defp pandeiro_slap(section, _pass) do
    hits = for {beat, vel} <- strokes(section, ["s"]), do: {beat, hit(vel: vel)}
    at(hits, 4)
  end

  # The beats the given strokes fall on in a pass, as {beat, vel}.
  defp strokes(section, letters) do
    for {cell, index} <- section |> cells() |> String.split() |> Enum.with_index(),
        stroke = String.trim_trailing(cell, ">"),
        stroke in letters do
      vel = if stroke == cell, do: vel(stroke), else: 0.9
      {index * 0.25, vel}
    end
  end

  # Each pass is two bars, a sixteenth to each cell: o is an open bass with the thumb, ox a closed
  # one, h the heel of the hand, f the fingertips, s a slap and . a rest; > accents a stroke.
  defp cells(:choro), do: "ox f h f  o f h f  ox f h f  o f h f"
  defp cells(:samba_de_roda), do: "o s . s  o f h f  o s . s  o f h f"
  defp cells(:baiao), do: "o f h o  o f h> f  o f h o  o s h f"
  defp cells(:forro), do: "o f h o  s h f o  o f h f>  h o f o"
  defp cells(:coco), do: "o f h o  f s h o  o f h s  h o o f"

  # mx's thumb has no closed bass, so ox is the thumb played softly.
  defp vel("o"), do: 0.75
  defp vel("ox"), do: 0.4
  defp vel("h"), do: 0.55
  defp vel("f"), do: 0.5
  defp vel("s"), do: 0.8
end
