defmodule Accordion do
  @moduledoc """
  A solo for the accordion's right hand written for mx, a bal-musette waltz in A minor, three
  beats to the bar.
  The musette register's two reeds beat on the low theme, the chords and the ending; the high
  theme plays dry, on one reed, with detune: 0.
  """

  use Mx.Song, tempo: 168

  part :theme, synth: :accordion
  part :high, synth: :accordion
  part :chords, synth: :accordion, defaults: [amp: 0.6]
  part :ending, synth: :accordion

  def song, do: repeat(form([:theme, :high, :chords, :theme, :ending], &accordion/1))

  defp accordion(:theme), do: part(:theme, line(theme(), []))
  defp accordion(:high), do: part(:high, line(theme(), octaves: 1, held: 0.45, detune: 0))
  defp accordion(:chords), do: part(:chords, chords())
  defp accordion(:ending), do: part(:ending, line(ending(), []))

  # Each word is a note and its length in beats, held `held` of its length, shifted by `octaves`.
  defp line(pattern, opts) do
    held = Keyword.get(opts, :held, 0.9)
    extra = Keyword.take(opts, [:detune])

    pattern
    |> steps(1,
      each: fn _step, beats ->
        [vel: if(beats < 1, do: 0.5, else: 0.6), sustain: beats * held, release: 0.1] ++ extra
      end
    )
    |> transpose(12 * Keyword.get(opts, :octaves, 0))
  end

  # Eight bars climbing from the low E to the D above, turning on a chromatic D# and falling home
  # to A.
  defp theme do
    ~MX"e3:1 a3:1 c4:1 b3:2 a3:1 gs3:1 b3:1 e4:1 d4:2 c4:1 b3:1 c4:1 d4:1 e4:1 f4:0.5 e4:0.5 ds4:1 e4:1 b3:1 gs3:1 a3:3"
  end

  # The waltz's chords in the right hand: struck on the first beat and short on the second and
  # third, two bars each of A minor and E7, then D minor, A minor, E7 and A minor.
  defp chords do
    voicings = %{am: ~w(a3 c4 e4)a, e7: ~w(gs3 d4 e4)a, dm: ~w(a3 d4 f4)a}

    seq([:am, :am, :e7, :e7, :dm, :am, :e7, :am], fn name ->
      chord = Enum.map(voicings[name], &pitch/1)

      seq([
        note(chord, 1, vel: 0.6, sustain: 0.9, release: 0.1),
        note(chord, 1, vel: 0.45, sustain: 0.35, release: 0.08),
        note(chord, 1, vel: 0.45, sustain: 0.35, release: 0.08)
      ])
    end)
  end

  defp ending, do: ~MX"e3:1 a3:1 c4:1 b3:2 a3:1 gs3:1 b3:1 e4:1 a3:6"
end
