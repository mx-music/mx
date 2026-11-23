defmodule Effects.Wah do
  @moduledoc """
  The wah on an electric bass playing a funk line in E: a filter that opens on each note, further
  the harder it is played, and closes as the note fades, the envelope filter of funk bass, guitar
  and clavinet that Wikipedia's "Auto-wah" describes, https://en.wikipedia.org/wiki/Auto-wah.
  Two bars of sixteenths, with loud notes on the beats and quiet ones between, play five times:

  1. dry;
  2. the wah as it comes: the loud notes open the filter and the quiet ones barely move it;
  3. `sensitivity: 12`, which raises the level it follows by 12 dB, so every note opens it and
     the loud ones open it all the way;
  4. that with `relax_ms: 40`, which shuts the filter soon after each note starts, a shorter
     and sharper sound;
  5. `cutoff_min: 88` and `cutoff_max: 52`, the other way round: each note closes the filter,
     which opens again as the note fades.

  The part sets the filter between the notes 40 and 88, lower than it comes, where a bass has
  its sound.
  """

  use Mx.Song, tempo: 100

  part :bass,
    synth: :electric_bass,
    defaults: [amp: 1.3],
    fx: [wah: [mix: 0, cutoff_min: 40, cutoff_max: 88]]

  def song do
    form([:dry, :defaults, :sensitive, :short, :closing], fn section ->
      part(:bass, together([line(), at(set(section), 8)]))
    end)
  end

  defp set(:dry), do: [{0, wah(mix: 0)}]
  defp set(:defaults), do: [{0, wah(mix: 1)}]
  defp set(:sensitive), do: [{0, wah(sensitivity: 12)}]
  defp set(:short), do: [{0, wah(relax_ms: 40)}]

  defp set(:closing) do
    [{0, wah(relax_ms: 150, cutoff_min: 88, cutoff_max: 52)}]
  end

  defp wah(opts), do: change({:bass, :wah}, opts)

  # The root on the one, its octave on the offbeats, and quiet notes between them.
  defp line do
    seq(
      for bar <- [
            [
              {28, 0.5, 0.9},
              {nil, 0.25, 0},
              {28, 0.25, 0.4},
              {40, 0.25, 0.8},
              {nil, 0.25, 0},
              {28, 0.25, 0.4},
              {38, 0.25, 0.7},
              {40, 0.5, 0.9},
              {28, 0.5, 0.5},
              {31, 0.5, 0.8},
              {33, 0.5, 0.7}
            ],
            [
              {28, 0.5, 0.9},
              {nil, 0.25, 0},
              {28, 0.25, 0.4},
              {40, 0.25, 0.8},
              {nil, 0.25, 0},
              {38, 0.25, 0.6},
              {40, 0.25, 0.8},
              {43, 0.5, 0.9},
              {40, 0.25, 0.5},
              {38, 0.25, 0.7},
              {35, 0.5, 0.8},
              {33, 0.5, 0.6}
            ]
          ],
          {note, beats, vel} <- bar do
        if note, do: note(note, beats, vel: vel), else: rest(beats)
      end
    )
  end
end
