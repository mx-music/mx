defmodule Effects.Order do
  @moduledoc """
  The order of a part's effects, heard on an electric guitar through a distortion and a reverb:
  `fx:` sends the sound through its effects in the order written, and the two orders are two
  sounds.
  Two bars of chords with a rest after each play twice:

  1. distortion, then reverb: a driven guitar in a room, the room clean behind each chord;
  2. reverb, then distortion: the room is driven too, so its ring comes up as loud as the chord
     and fills the rests with buzz.
  """

  use Mx.Song, tempo: 84

  @distortion {:distortion, [distort: 0.8, amp: 0.2]}
  @reverb {:reverb, [room: 0.8, mix: 0.4]}

  part :driven_first, synth: :electric_guitar, defaults: [amp: 2], fx: [@distortion, @reverb]
  part :room_first, synth: :electric_guitar, defaults: [amp: 2], fx: [@reverb, @distortion]

  def song do
    form([:driven_first, :room_first], fn section -> part(section, chords()) end)
  end

  # E, G, A and E as power chords, each cut short and followed by silence.
  defp chords do
    seq(
      for _bar <- 1..2, root <- [40, 43, 45, 40] do
        seq([note([root, root + 7, root + 12], 1, vel: 0.8, sustain: 0.4), rest(1)])
      end
    )
  end
end
