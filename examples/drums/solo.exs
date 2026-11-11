import Mx

# A solo for the drum kit written for mx: a rock beat that opens on a crash, the same beat with the hi-hat opening and the pedal closing it, ghost notes on the snare between its hardest strokes, a fill down the toms, and a last crash that rings and is choked.
defmodule Drums do
  import Mx

  # A beat is a quarter note of 4/4, so a pass is a bar, written as sixteen cells to a drum.

  # The rock beat: eighths on the closed hi-hat, the snare on the second and fourth beats, and the kick on the first and third and the eighth after the third.
  def beat do
    [
      closed_hihat: "x.o.x.o.x.o.x.o.",
      snare: "....X.......X...",
      kick: "X.......X.X....."
    ]
  end

  def cells(:intro), do: [crash: "X..............."] ++ beat()
  def cells(:groove), do: beat()

  # The hi-hat opens on the eighth after the second and fourth beats, and the pedal closes it on the next beat.
  def cells(:open) do
    Keyword.merge(beat(), closed_hihat: "x.o.x...x.o.x...", open_hihat: "......o.......o.")
  end

  # The snare's softest strokes, g, between its hardest, X, over the closed hi-hat and the kick.
  def cells(:ghosts) do
    [closed_hihat: "x.o.x.o.x.o.x.o.", snare: "g.ggX.g.g.ggX.gX", kick: "X.......X.X....."]
  end

  # Down the toms in sixteenths, high, mid and low, then the low tom and the snare together.
  def cells(:fill) do
    [
      high_tom: "xxxx............",
      mid_tom: "....xxxx........",
      low_tom: "........xxxx.X.X",
      snare: "............X.X.",
      kick: "X.......X......."
    ]
  end

  # A crash on the first beat, rung for three beats and then choked, with the kick.
  def cells(:ending), do: [crash: "C...............", kick: "X..............."]

  def vel("g"), do: 0.3
  def vel("o"), do: 0.55
  def vel("x"), do: 0.75
  def vel(_), do: 1

  # The kick is mx's own, written by ear, and takes amp where the measured drums take vel; every drum plays at half its level, so strokes together stay below full scale.
  def loudness(:kick, letter), do: [amp: vel(letter) / 2]
  def loudness(_drum, letter), do: [vel: vel(letter)]

  # How long the open hi-hat rings before the pedal closes it, and the ending's crash before it is choked.
  def held("o", :open_hihat), do: [sustain: 0.5, release: 0.05]
  def held("C", :crash), do: [sustain: 3, release: 0.1]
  def held(_, _), do: []

  # The strokes of a pass on one drum, as {beat, options}.
  def strokes(section, drum) do
    letters = section |> cells() |> Keyword.get(drum, "") |> String.graphemes()

    for {letter, index} <- Enum.with_index(letters),
        letter != ".",
        do: {index / 4, loudness(drum, letter) ++ held(letter, drum)}
  end

  # A pass of kick, as 4 beats.
  def kick(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :kick), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of snare, as 4 beats.
  def snare(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :snare), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of closed_hihat, as 4 beats.
  def closed_hihat(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :closed_hihat), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of open_hihat, as 4 beats.
  def open_hihat(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :open_hihat), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of high_tom, as 4 beats.
  def high_tom(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :high_tom), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of mid_tom, as 4 beats.
  def mid_tom(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :mid_tom), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of low_tom, as 4 beats.
  def low_tom(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :low_tom), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # A pass of crash, as 4 beats.
  def crash(section, _pass) do
    hits = for {beat, opts} <- strokes(section, :crash), do: {beat, hit(opts)}
    at(hits, 4)
  end

  # The form, each of its passes a section.
  def form do
    sections =
      for {section, count} <- [intro: 1, groove: 1, open: 2, ghosts: 1, fill: 1, ending: 1],
          _ <- 1..count,
          do: section

    Enum.with_index(sections, fn section, pass ->
      together([
        part(:kick, kick(section, pass), synth: :kick),
        part(:snare, snare(section, pass), synth: :snare, defaults: [amp: 0.5]),
        part(:closed_hihat, closed_hihat(section, pass),
          synth: :closed_hihat,
          defaults: [amp: 0.5]
        ),
        part(:open_hihat, open_hihat(section, pass), synth: :open_hihat, defaults: [amp: 0.5]),
        part(:high_tom, high_tom(section, pass), synth: :high_tom, defaults: [amp: 0.5]),
        part(:mid_tom, mid_tom(section, pass), synth: :mid_tom, defaults: [amp: 0.5]),
        part(:low_tom, low_tom(section, pass), synth: :low_tom, defaults: [amp: 0.5]),
        part(:crash, crash(section, pass), synth: :crash, defaults: [amp: 0.5])
      ])
    end)
  end
end

song(tempo: 100, music: repeat(seq(Drums.form())))
