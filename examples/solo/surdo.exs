import Mx

# A piece for the three surdos of a samba bateria written for mx, in 2/4, two beats to the bar.
# The surdo de primeira holds the marcação, muted on the first beat of each bar and open on the second; the higher surdo de segunda answers it open on the first beat; the surdo de terceira cuts across them in sixteenths.
defmodule Surdos do
  import Mx

  def primeira_note, do: 36.31
  def segunda_note, do: 41
  def terceira_note, do: 45

  # Eight bars of the marcação: muted on the first beat, open on the second, the last bar's open stroke a little harder.
  def primeira do
    strokes =
      for bar <- 0..7 do
        [
          {2 * bar, hit(note: primeira_note(), muted: 1, vel: 0.5)},
          {2 * bar + 1, hit(note: primeira_note(), vel: if(bar == 7, do: 0.85, else: 0.7))}
        ]
      end

    at(List.flatten(strokes), 16)
  end

  # The segunda answers on the first beat, and in every second bar with a muted pickup on the last sixteenth.
  def segunda do
    strokes =
      for bar <- 0..7 do
        pickup =
          if rem(bar, 2) == 1 do
            [{2 * bar + 1.75, hit(note: segunda_note(), muted: 1, vel: 0.4)}]
          else
            []
          end

        [{2 * bar, hit(note: segunda_note(), vel: 0.65)} | pickup]
      end

    at(List.flatten(strokes), 16)
  end

  # The terceira's cuts over two bars, in sixteenths: two off the beat in the first bar, then a muted stroke and three open ones around the second bar's second beat; the fill adds two muted strokes between them.
  @cuts [
    {0.75, 0, 0.6},
    {1.5, 0, 0.55},
    {2.25, 1, 0.4},
    {2.75, 0, 0.6},
    {3.0, 0, 0.5},
    {3.5, 0, 0.65}
  ]

  def terceira(fill) do
    phrase = if fill, do: @cuts ++ [{3.25, 1, 0.35}, {3.75, 1, 0.35}], else: @cuts

    strokes =
      for repeat <- 0..3, {beat, muted, vel} <- phrase do
        {4 * repeat + beat, hit(note: terceira_note(), muted: muted, vel: vel)}
      end

    at(strokes, 16)
  end

  def section(parts) do
    together(for {name, music} <- parts, do: part(name, music, synth: :surdo))
  end

  def form do
    seq([
      section(primeira: primeira()),
      section(primeira: primeira(), segunda: segunda()),
      section(primeira: primeira(), segunda: segunda(), terceira: terceira(false)),
      section(primeira: primeira(), segunda: segunda(), terceira: terceira(true))
    ])
  end
end

song(tempo: 132, music: repeat(Surdos.form()))
