defmodule Bongos do
  @moduledoc """
  A solo for the bongos written for mx from how the bongocero plays in son and salsa: the
  martillo, the hammer, a steady bar of eight strokes, left to play freer phrases, the repiques,
  and taken up again.
  The martillo is eight eighths, most of them on the small drum, the macho, and the seventh on the
  large one, the hembra, as https://www.x8drums.com/blog/martillo-bongo-rhythm describes; the same
  page gives the heel-tip stroke some bongoceros play on the fourth and eighth.
  Every second bar ends on the variation https://www.artdrum.com/ESSAY_BONGO_BASICS.HTM calls the
  most common: the last thumb stroke becomes an accented rim shot on the macho.
  The repiques are written for mx: accents every third sixteenth over soft strokes, quarter-note
  triplets across the two drums, the offbeats and the fourth beat as the bongó plays them in
  changüí, by Wikipedia's article on the bongo, and ruffs, the fingers rolled into an accent,
  before a roll that grows into the last stroke.
  """

  use Mx.Song, tempo: 180

  # A beat is a quarter note of 4/4, so a pass is a bar, written as eight cells of eighths to a
  # drum, twelve of triplets or sixteen of sixteenths.
  # In the martillo M is a stroke of the index finger on the macho with the thumb resting on the
  # head, t a soft stroke of the thumb, o the macho's open tone, h a heel-tip stroke and R a rim
  # shot; on the hembra O is its open tone.
  # In the repiques O is an accent, o a stroke, g a soft stroke and r a ruff, three soft strokes
  # rolled into an accent.
  @martillo [high_bongo: "MtotMt.t", low_bongo: "......O."]
  @rim_shot [high_bongo: "MtotMt.R", low_bongo: "......O."]
  @heel_tip [high_bongo: "MtohMt.h", low_bongo: "......O."]

  # How far apart a ruff's strokes are, in beats.
  @ruff 0.07

  # The hembra is the louder of the two drums, so it plays a little under the macho.
  part :high_bongo, synth: :high_bongo, defaults: [amp: 1.5]
  part :low_bongo, synth: :low_bongo, defaults: [amp: 1.05]

  # The form, each of its passes a bar.
  def song, do: repeat(seq(bars(), &drums/1))

  # A bar of the two drums, each silent where the bar gives it no cells.
  defp drums(cells) do
    together([:high_bongo, :low_bongo], &part(&1, bar(Keyword.get(cells, &1, ""))))
  end

  defp bars do
    [
      @martillo,
      @rim_shot,
      @heel_tip,
      @heel_tip,
      @martillo,
      @rim_shot,
      [high_bongo: "OggO ggOg gOgg OggO"],
      [high_bongo: "ggOg gOgg O... ....", low_bongo: ".... .... .... O..."],
      @martillo,
      @rim_shot,
      [high_bongo: "O.O ... O.O ...", low_bongo: "... .O. ... .O."],
      [high_bongo: "ogo ogo ogo ...", low_bongo: "... ... ... O.O"],
      @martillo,
      @rim_shot,
      [high_bongo: ".O.O.O.O", low_bongo: "......O."],
      [high_bongo: "..O. ..O. ..OO ..O.", low_bongo: ".... .... .... O..."],
      @martillo,
      @rim_shot,
      [high_bongo: ".r.r.r..", low_bongo: "......O."],
      [high_bongo: "gggg gggg oooo OOOO"],
      [high_bongo: "R", low_bongo: "O"]
    ]
  end

  # A bar of one drum, as 4 beats.
  defp bar(cells) do
    letters = cells |> String.replace(" ", "") |> String.graphemes()
    per_beat = length(letters) / 4

    hits =
      for {letter, index} <- Enum.with_index(letters),
          letter != ".",
          {offset, opts} <- strokes(letter) do
        beat = Float.round(index / per_beat + offset, 3)
        {beat, hit(opts)}
      end

    if hits == [], do: rest(4), else: at(hits, 4)
  end

  # mx's muted stroke rings as long as the open one, as on the recordings, so the martillo's
  # strokes differ mostly in how hard they are played.
  defp strokes("M"), do: [{0, [muted: 1, vel: 0.8]}]
  defp strokes("t"), do: [{0, [muted: 1, vel: 0.4]}]
  defp strokes("h"), do: [{0, [muted: 1, vel: 0.25]}]
  defp strokes("R"), do: [{0, [vel: 1]}]
  defp strokes("O"), do: [{0, [vel: 0.85]}]
  defp strokes("o"), do: [{0, [vel: 0.7]}]
  defp strokes("g"), do: [{0, [vel: 0.45]}]

  defp strokes("r") do
    graces = for step <- 3..1//-1, do: {-step * @ruff, [vel: 0.45]}
    graces ++ [{0, [vel: 0.9]}]
  end
end
