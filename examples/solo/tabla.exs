import Mx

# A solo for the tabla written for mx in teentaal: sixteen beats in four vibhags of four, with the theka Wikipedia gives, dha dhin dhin dha, dha dhin dhin dha, then the khali and ta dhin dhin dha.
defmodule Tabla do
  import Mx

  # The khali, beats 9 to 12, is played without the bayan, the left drum, so it opens on na, the right-hand bol Wikipedia marks it with, rather than dha.
  # It plays the theka, a faster variation that splits each beat in two, then the theka with the bayan bent upwards as the palm presses it, and the theka again.

  # A word to each beat of the cycle; a dot splits a beat in two, and ~ bends the bayan two semitones up while it rings.
  def bols(:theka), do: "dha dhin dhin dha  dha dhin dhin dha  na tin tin na  ta dhin dhin dha"

  def bols(:variation) do
    "dha.te dhin.na dhin.na dha.te  dha.te dhin.na dhin.na dha.ge  na.ke tin.na tin.na na.ke  ta.te dhin.na dhin.na dha.te"
  end

  def bols(:bends) do
    "dha dhin~ dhin dha  dha dhin dhin dha~  na tin tin na  ta dhin~ dhin dha~"
  end

  # Each bol as the dayan's stroke and the bayan's, nil where that hand rests: dha is na over ghe, and dhin is tun over ghe.
  def strokes("dha"), do: {:tabla_na, :tabla_ghe}
  def strokes("dhin"), do: {:tabla_tun, :tabla_ghe}
  def strokes("tin"), do: {:tabla_tun, nil}
  def strokes("na"), do: {:tabla_na, nil}
  def strokes("ta"), do: {:tabla_na, nil}
  def strokes("te"), do: {:tabla_te, nil}
  def strokes("ge"), do: {nil, :tabla_ghe}
  def strokes("ke"), do: {nil, :tabla_ke}

  def vel(beat, _bol) when beat == 0, do: 0.9
  def vel(_beat, "te"), do: 0.45
  def vel(_beat, "ke"), do: 0.5
  def vel(_beat, _bol), do: 0.65

  # The beats a synth plays in a pass, as {beat, vel, bend}.
  def hits(section, synth) do
    for {word, beat} <- section |> bols() |> String.split() |> Enum.with_index(),
        halves = String.split(word, "."),
        {half, index} <- Enum.with_index(halves),
        bol = String.trim_trailing(half, "~"),
        synth in Tuple.to_list(strokes(bol)) do
      at = beat + index / length(halves)
      {at, vel(at, bol), String.ends_with?(half, "~")}
    end
  end

  # A pass of tabla_na, as 16 beats.
  def tabla_na(section, _pass) do
    hits = for {beat, vel, _bend} <- hits(section, :tabla_na), do: {beat, hit(vel: vel)}
    at(hits, 16)
  end

  # A pass of tabla_tun, as 16 beats.
  def tabla_tun(section, _pass) do
    hits = for {beat, vel, _bend} <- hits(section, :tabla_tun), do: {beat, hit(vel: vel)}
    at(hits, 16)
  end

  # A pass of tabla_te, as 16 beats.
  def tabla_te(section, _pass) do
    hits = for {beat, vel, _bend} <- hits(section, :tabla_te), do: {beat, hit(vel: vel)}
    at(hits, 16)
  end

  # A pass of tabla_ke, as 16 beats.
  def tabla_ke(section, _pass) do
    hits = for {beat, vel, _bend} <- hits(section, :tabla_ke), do: {beat, hit(vel: vel)}
    at(hits, 16)
  end

  # A pass of tabla_ghe, as 16 beats; a bent stroke glides up as the heel presses the head.
  def tabla_ghe(section, _pass) do
    hits =
      for {beat, vel, bend} <- hits(section, :tabla_ghe) do
        if bend do
          {beat, hit(vel: vel, note_slide: 0.5, changes: [{0, note: 44.25}])}
        else
          {beat, hit(vel: vel)}
        end
      end

    at(hits, 16)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [theka: 2, variation: 2, bends: 2, theka: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:tabla_na, tabla_na(section, pass), synth: :tabla_na),
        part(:tabla_tun, tabla_tun(section, pass), synth: :tabla_tun),
        part(:tabla_te, tabla_te(section, pass), synth: :tabla_te),
        part(:tabla_ke, tabla_ke(section, pass), synth: :tabla_ke),
        part(:tabla_ghe, tabla_ghe(section, pass), synth: :tabla_ghe)
      ])
    end)
  end
end

song(tempo: 90, music: repeat(seq(Tabla.form())))
