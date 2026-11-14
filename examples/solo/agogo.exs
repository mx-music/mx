defmodule Agogo do
  @moduledoc """
  A beat is a quarter note of samba's cut time, so a pass is two bars, the length of a bell
  figure.
  """

  use Mx.Song, tempo: 200

  part :low_agogo, synth: :low_agogo
  part :high_agogo, synth: :high_agogo

  def song do
    repeat(seq(form()))
  end

  # The form, each of its passes a section.
  defp form do
    sections =
      for {section, count} <- [
            samba: 4,
            partido: 4,
            maracatu: 4,
            accents: 2,
            one: 2,
            two: 2,
            three: 2,
            four: 2
          ],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:low_agogo, low_agogo(section, pass)),
        part(:high_agogo, high_agogo(section, pass))
      ])
    end)
  end

  # A pass of low_agogo, as 8 beats.
  defp low_agogo(section, _pass) do
    hits = for {beat, vel} <- strokes(section, :low), do: {beat, hit(vel: vel)}
    at(hits, 8)
  end

  # A pass of high_agogo, as 8 beats.
  defp high_agogo(section, _pass) do
    hits = for {beat, vel} <- strokes(section, :high), do: {beat, hit(vel: vel)}
    at(hits, 8)
  end

  # The beats each bell strikes in a pass, as {beat, vel}.
  # The samba and partido alto figures are two of the common samba bell patterns; the maracatu
  # figure is written for mx, in sixteenths at half the pulse.
  defp strokes(:samba, :low), do: [{0, 0.7}, {3.5, 0.5}, {4, 0.7}, {7.5, 0.5}]
  defp strokes(:samba, :high), do: [{1, 0.6}, {2, 0.6}, {5.5, 0.6}, {6, 0.6}]
  defp strokes(:partido, :low), do: [{2.5, 0.7}, {5.5, 0.6}, {6.5, 0.5}, {7, 0.7}]
  defp strokes(:partido, :high), do: [{0, 0.8}, {1, 0.6}, {3.5, 0.7}]
  defp strokes(:maracatu, :low), do: [{0, 0.9}, {4, 0.7}, {6, 0.8}]

  defp strokes(:maracatu, :high) do
    [{1.5, 0.6}, {3, 0.6}, {3.5, 0.5}, {5, 0.6}, {7, 0.6}, {7.5, 0.5}]
  end

  # Eighths alternating high and low, with accents where the samba figure strikes and ghost
  # strokes between.
  defp strokes(:accents, bell) do
    accented = for {beat, _vel} <- strokes(:samba, :low) ++ strokes(:samba, :high), do: beat
    first = if bell == :high, do: 0, else: 0.5

    for beat <- Enum.map(0..7, &(&1 + first)) do
      {beat, if(beat in accented, do: 1, else: 0.3)}
    end
  end

  # A cell is half a beat here; the accent on each sixteenth that starts a beat of 2/4 is mx's
  # own, since the patterns mark none.
  defp strokes(section, bell) when section in [:one, :two, :three, :four] do
    letter = if bell == :high, do: "H", else: "L"

    for {cell, index} <- section |> cells() |> String.split() |> Enum.with_index(),
        {stroke, half} <- cell |> String.graphemes() |> Enum.with_index(),
        stroke == letter do
      vel = if rem(index, 4) == 0 and half == 0, do: 0.8, else: 0.55
      {index * 0.5 + half * 0.5 / String.length(cell), vel}
    end
  end

  # Four samba agogô patterns from
  # https://kkfsamba2014.wordpress.com/2014/10/01/samba-patterns-for-agogo-bells/, a sixteenth of
  # samba's 2/4 to each cell:
  # H strikes the high bell, L the low one and O rests; a cell of two, such as HL or OH, splits
  # its sixteenth in two.
  defp cells(:one), do: "H H L O  H H L O  H H L O  H H L O"
  defp cells(:two), do: "HL OH L O  HL OH L O  HL OH L O  HL OH L O"
  defp cells(:three), do: "L H L HL  OH OH L H  L H L H  OH OH L H"
  defp cells(:four), do: "H H L LH  OH OH L L  H H L LH  OH OH L L"
end
