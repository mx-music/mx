defmodule Maracatu do
  @moduledoc """
  A maracatu de baque virado, the maracatu of the nações of Recife, on mx's synth percussion.
  Every pattern is one the Nação Estrela Brilhante do Recife plays, as Daniel Barbosa notated them
  and Pedro Henrique Izar de Souza and Claudio Dauelsberg print them in "Maracatu Nação Estrela
  Brilhante do Recife: baques e sua adaptação para o piano" (ANPPOM, 2025): the gonguê's two
  patterns, the mineiro, the agbê, the caixa and the tarol, the alfaias' baques de marcação,
  arrasto, imalê and martelo, and the virada the alfaias play between two sections.
  The high instruments play the same patterns under every baque, and the alfaias say which baque
  it is.
  The tempo, the order of the baques, eight bars to each, and which gonguê pattern goes with which
  baque are mx's own.
  cowbell plays the gonguê, ganza the mineiro, cabasa the agbê, snare the caixa and the tarol, and
  surdo the alfaias, at two tunings below its own and partly muted, so the stroke is drier.
  """

  use Mx.Song, tempo: 104

  @room [reverb: [decay_seconds: 1.2, damp: 0.6, mix: 0.12]]

  part :gongue, synth: :cowbell, defaults: [amp: 0.3, pan: 0.15, note: 65], fx: @room
  part :mineiro, synth: :ganza, defaults: [amp: 0.55, pan: -0.4], fx: @room
  part :agbe, synth: :cabasa, defaults: [amp: 0.4, pan: 0.4], fx: @room
  part :caixa, synth: :snare, defaults: [amp: 0.65, pan: -0.2], fx: @room
  part :tarol, synth: :snare, defaults: [amp: 0.5, pan: 0.25, note: 58], fx: @room

  part :low_alfaia,
    synth: :surdo,
    defaults: [amp: 0.6, pan: -0.15, note: 31, muted: 0.6],
    fx: @room

  part :high_alfaia,
    synth: :surdo,
    defaults: [amp: 0.5, pan: 0.15, note: 36, muted: 0.6],
    fx: @room

  def song do
    repeat(seq([:marcacao, :arrasto, :imale, :martelo], &baque/1))
  end

  # Eight bars of a baque: the alfaias play it seven times and then the virada, which leads to the
  # next baque.
  defp baque(baque) do
    together([
      part(:gongue, gongue(baque)),
      part(:mineiro, mineiro()),
      part(:agbe, agbe()),
      part(:caixa, caixa(~MX"AggAAgBgAAgAAgBg"s)),
      part(:tarol, caixa(~MX"AAgAAgBgAAgAAgBg"s)),
      part(:low_alfaia, alfaia(baque)),
      part(:high_alfaia, alfaia(baque))
    ])
  end

  # The gonguê's bar in sixteenths: its first pattern starts a sixteenth after the beat, and its
  # second fills the beats in.
  defp gongue(baque) do
    bar =
      if baque in [:marcacao, :arrasto] do
        ~MX".x..x.x..x..x.x."s
      else
        ~MX"x.xxx.x.xx.xx.x."s
      end

    bar |> List.duplicate(8) |> steps(0.25, vel: 0.7)
  end

  # The mineiro shakes sixteenths with the third of each beat accented: d is down and u is up, in
  # capitals where accented.
  defp mineiro do
    strokes = [d: [vel: 0.45, up: 0], u: [vel: 0.45, up: 1], D: [vel: 0.85, up: 0]]
    pattern = List.duplicate(~MX"duDu"s, 32)
    steps(pattern, 0.25, strokes: strokes)
  end

  # The agbê plays an eighth and two sixteenths to a beat.
  defp agbe do
    strokes = [X: [vel: 0.8], x: [vel: 0.55]]
    pattern = List.duplicate(~MX"X.xx"s, 32)
    steps(pattern, 0.25, strokes: strokes)
  end

  # Eight bars of a caixa's bar of sixteenths: A is an accent, g a soft stroke between accents and
  # B an accent the stick buzzes after.
  defp caixa(bar) do
    strokes = [A: [vel: 0.85], B: [vel: 0.85, buzz: 1], g: [vel: 0.3]]
    bar |> List.duplicate(8) |> steps(0.25, strokes: strokes)
  end

  # A baque's bar on the alfaia seven times, then the virada.
  # D is the right hand, which holds the heavy stick, and E the left, which holds the thin one;
  # a capital is an accent.
  defp alfaia(baque) do
    strokes = [D: [vel: 0.95], d: [vel: 0.8], E: [vel: 0.7], e: [vel: 0.45]]
    bars = List.duplicate(bar(baque), 7) ++ [~MX"e.D.e.D.eD.De.D."s]
    steps(bars, 0.25, strokes: strokes)
  end

  defp bar(:marcacao), do: ~MX"D.......eD..eD.."s
  defp bar(:arrasto), do: ~MX"D...eD..eD..eD.."s
  defp bar(:imale), do: ~MX"D...E.D.eD..eD.."s
  defp bar(:martelo), do: ~MX"ed.de.d.ed.de..."s
end
