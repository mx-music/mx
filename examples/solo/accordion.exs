# A solo for the accordion's right hand written for mx, a bal-musette waltz in A minor, three
# beats to the bar.
# The musette register's two reeds beat on the low theme, the chords and the ending; the high
# theme plays dry, on one reed, with detune: 0.
defmodule Accordion do
  use Mx.Song, tempo: 168

  @steps %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}

  part :theme, synth: :accordion
  part :high, synth: :accordion
  part :chords, synth: :accordion, defaults: [amp: 0.6]
  part :ending, synth: :accordion

  def song do
    repeat(form())
  end

  defp form do
    seq([
      part(:theme, line(theme(), [])),
      part(:high, line(theme(), octaves: 1, held: 0.45, detune: 0)),
      part(:chords, chords()),
      part(:theme, line(theme(), [])),
      part(:ending, line(ending(), []))
    ])
  end

  # Each token is a note and its length in beats, held `held` of its length, shifted by `octaves`.
  defp line(tokens, opts) do
    octaves = Keyword.get(opts, :octaves, 0)
    held = Keyword.get(opts, :held, 0.9)
    extra = Keyword.take(opts, [:detune])

    seq(
      for token <- String.split(tokens) do
        [name, beats] = String.split(token, ":")
        {beats, _} = Float.parse(beats)

        note(
          midi(name) + 12 * octaves,
          beats,
          [vel: if(beats < 1, do: 0.5, else: 0.6), sustain: beats * held, release: 0.1] ++ extra
        )
      end
    )
  end

  # Eight bars climbing from the low E to the D above, turning on a chromatic D# and falling home
  # to A.
  defp theme do
    "E3:1 A3:1 C4:1 B3:2 A3:1 G#3:1 B3:1 E4:1 D4:2 C4:1 B3:1 C4:1 D4:1 E4:1 F4:0.5 E4:0.5 D#4:1 E4:1 B3:1 G#3:1 A3:3"
  end

  # The waltz's chords in the right hand: struck on the first beat and short on the second and
  # third, two bars each of A minor and E7, then D minor, A minor, E7 and A minor.
  defp chords do
    voicings = %{am: ~w(A3 C4 E4), e7: ~w(G#3 D4 E4), dm: ~w(A3 D4 F4)}

    seq(
      for name <- [:am, :am, :e7, :e7, :dm, :am, :e7, :am] do
        chord = Enum.map(voicings[name], &midi/1)

        seq([
          note(chord, 1, vel: 0.6, sustain: 0.9, release: 0.1),
          note(chord, 1, vel: 0.45, sustain: 0.35, release: 0.08),
          note(chord, 1, vel: 0.45, sustain: 0.35, release: 0.08)
        ])
      end
    )
  end

  defp ending, do: "E3:1 A3:1 C4:1 B3:2 A3:1 G#3:1 B3:1 E4:1 A3:6"

  # A note name such as G#3 as its MIDI note.
  defp midi(name) do
    [_, letter, sharp, octave] = Regex.run(~r/^([A-G])(#?)(\d)$/, name)
    12 * (String.to_integer(octave) + 1) + @steps[letter] + if(sharp == "#", do: 1, else: 0)
  end
end
