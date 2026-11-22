defmodule DialTone do
  @moduledoc """
  Dial Tone, an electro track in G minor at 126 bpm made only of the electronic samples Sonic Pi
  ships, which are under Creative Commons 0.
  The beat is electro's: the 808 kick pushed off the beat, a snare and a snap on two and four,
  sixteenth hats and a cowbell.
  The bass is bass_trance_c and the arpeggio elec_blip, each a single note moved to the others by
  its rate, over four bars of G minor, G minor, E flat and F.
  The pads, the robot voices and the telephone are the pack's tbd, mehackit and glitch samples as
  recorded.
  Download them with mx samples download sonic_pi.
  """

  use Mx.Song, tempo: 126

  part :kick, fx: [level: [amp: 0.65]]
  part :snare, fx: [level: [amp: 0.5], reverb: [decay_seconds: 1.2, mix: 0.15]]
  part :hats, fx: [level: [amp: 0.3], pan: [pan: 0.25]]
  part :bells, fx: [level: [amp: 0.35], pan: [pan: -0.3]]

  part :clicks,
    fx: [level: [amp: 0.3], echo: [phase: 0.375, decay: 2, mix: 0.3], pan: [pan: -0.4]]

  part :bass, fx: [level: [amp: 0.33]]
  part :arp, fx: [level: [amp: 0.8], echo: [phase: 0.75, decay: 3, mix: 0.35], pan: [pan: 0.3]]
  part :pads, fx: [level: [amp: 0.35], reverb: [decay_seconds: 3.2, mix: 0.4]]
  part :voices, fx: [level: [amp: 0.4], echo: [phase: 0.5, decay: 3, mix: 0.3]]
  part :bed, fx: [level: [amp: 0.5]]

  # The bass, from its C: the root and its octave, with the notes that lead on.
  @bass [
    [7, nil, 7, 19, nil, 7, nil, 10, 7, nil, 7, 19, nil, 5, nil, 14],
    [7, nil, 7, 19, nil, 7, nil, 10, 7, nil, 19, 7, nil, 10, 12, 14],
    [3, nil, 3, 15, nil, 3, nil, 7, 3, nil, 3, 15, nil, 3, nil, 10],
    [5, nil, 5, 17, nil, 5, nil, 9, 5, nil, 17, 5, nil, 9, 12, 14]
  ]

  # The arpeggio, from the blip's D: each chord up and down.
  @arp [
    [5, 8, 12, 8, 5, 8, 12, 17, 12, 8, 5, 8, 12, 8, 5, 0],
    [5, 8, 12, 8, 5, 8, 12, 17, 20, 17, 12, 8, 12, 17, 12, 8],
    [1, 5, 8, 13, 8, 5, 1, 5, 8, 13, 17, 13, 8, 5, 8, 13],
    [3, 7, 10, 15, 10, 7, 3, 7, 10, 15, 19, 15, 10, 7, 10, 15]
  ]

  def song do
    seq([intro(), build(), main(), middle(), last(), ending()])
  end

  # The telephone dials over the pads, and the hats come in.
  defp intro do
    together(
      bed: sample({:sonic_pi, :tbd_fxbed_loop}, 16),
      pads: pads(1),
      voices:
        seq([
          sample({:sonic_pi, :mehackit_phone1}, 4),
          sample({:sonic_pi, :mehackit_phone2}, 4),
          sample({:sonic_pi, :mehackit_phone4}, 4),
          sample({:sonic_pi, :mehackit_phone3}, 4)
        ]),
      hats: seq([rest(8), strokes(:hat_cab, ~MX"7353735373537353"s, 2)]),
      clicks: seq([rest(8), strokes(:elec_tick, ~MX"9..9..9..9..9.9."s, 2)])
    )
  end

  # The kick and the bass.
  defp build do
    together(
      [bass: bass(1), clicks: strokes(:elec_tick, ~MX"9..9..9..9..9.9."s, 4)] ++
        beat(4) ++ [snare: seq([rest(12), strokes(:elec_hi_snare, ~MX"....5.5.5.667789"s)])]
    )
  end

  # Eight bars of everything, the robots answering.
  defp main do
    together(
      [
        bass: bass(2),
        arp: arp(2),
        pads: pads(2),
        bells: strokes(:drum_cowbell, [~MX"..6..6....6.6..."s, ~MX"..6..6....6..6.6"s], 4),
        voices: voices(~w(mehackit_robot1 mehackit_robot3 mehackit_robot2 mehackit_robot5)a)
      ] ++ beat(8) ++ backbeat(8)
    )
  end

  # Four bars without the kick: pads, glitches and a snare that fills up.
  defp middle do
    together(
      pads: pads(1),
      arp: arp(1, -12),
      voices: voices(~w(glitch_robot1 glitch_robot2)a),
      clicks:
        seq([
          strokes(:glitch_perc2, ~MX"9.......7......."s),
          strokes(:glitch_perc4, ~MX"....9.......9..."s),
          strokes(:tbd_perc_blip, ~MX"9.9.9.9.99999999"s, 2)
        ]),
      snare:
        seq([rest(8), strokes(:elec_hi_snare, [~MX"4...4...4...4.4."s, ~MX"5.5.5.5.66667789"s])])
    )
  end

  # Twelve bars, the arpeggio an octave up for the last eight.
  defp last do
    together(
      [
        bass: bass(3),
        arp: seq([arp(1), arp(2, 12)]),
        pads: pads(3),
        bells: strokes(:drum_cowbell, [~MX"..6..6....6.6..."s, ~MX"..6..6....6..6.6"s], 6),
        clicks: strokes(:elec_twip, ~MX"......6.......6."s, 12),
        voices:
          voices(
            ~w(mehackit_robot4 mehackit_robot6 mehackit_robot1 mehackit_robot5 mehackit_robot3 mehackit_robot2)a
          )
      ] ++ beat(12) ++ backbeat(12)
    )
  end

  # A last kick, a chime and a robot.
  defp ending do
    together(
      kick: sample({:sonic_pi, :bd_808}, 8),
      bells: sample({:sonic_pi, :elec_chime}, 8),
      pads: sample({:sonic_pi, :tbd_pad_1}, 8, release: 2),
      voices: seq([rest(1), sample({:sonic_pi, :mehackit_robot7}, 7)])
    )
  end

  defp pads(times) do
    repeat(
      seq([
        sample({:sonic_pi, :tbd_pad_1}, 4, attack: 0.2, release: 0.5),
        sample({:sonic_pi, :tbd_pad_2}, 4, attack: 0.2, release: 0.5),
        sample({:sonic_pi, :tbd_pad_4}, 4, attack: 0.2, release: 0.5),
        sample({:sonic_pi, :tbd_pad_3}, 4, attack: 0.2, release: 0.5)
      ]),
      times
    )
  end

  # Bars of one sample in sixteenths, a character to each: a digit is a stroke of that level, a
  # dot is silence.
  defp strokes(name, patterns, bars \\ 1)

  defp strokes(name, [%{} | _] = pattern, bars), do: strokes(name, [pattern], bars)

  defp strokes(name, patterns, bars) do
    levels =
      for {stroke, strength} <- Enum.zip(~w(1 2 3 4 5 6 7 8 9)a, 1..9),
          do: {stroke, [amp: strength / 9]}

    bar = fn pattern -> steps(pattern, 0.25, sample: {:sonic_pi, name}, strokes: levels) end
    repeat(seq(patterns, bar), bars)
  end

  defp bass(times), do: repeat(seq(@bass, fn bar -> line(:bass_trance_c, bar) end), times)

  defp beat(bars) do
    [
      kick: strokes(:bd_808, [~MX"9..7..9.....9..."s, ~MX"9..7..9...7.9..."s], div(bars, 2)),
      hats:
        together([
          strokes(:hat_cab, ~MX"7353735373537353"s, bars),
          strokes(:hat_gnu, [~MX"..............5."s, ~MX"......5.......5."s], div(bars, 2))
        ])
    ]
  end

  defp arp(times, up \\ 0) do
    repeat(
      seq(@arp, fn bar -> line(:elec_blip, Enum.map(bar, &(&1 + up)), 1.5) end),
      times
    )
  end

  # A voice at the start of every other bar.
  defp voices(names) do
    seq(names, fn name -> sample({:sonic_pi, name}, 8) end)
  end

  defp backbeat(bars) do
    [
      snare:
        together([
          strokes(:elec_snare, ~MX"....8.......8..."s, bars),
          strokes(:perc_snap, ~MX"....6.......6..3"s, bars)
        ])
    ]
  end

  # A bar of a pitched sample in sixteenths, as semitones from its recorded note, nil a silent
  # step.
  defp line(name, notes, amp \\ 1.0) do
    hits =
      for {note, index} <- Enum.with_index(notes), note != nil do
        {index / 4,
         sample({:sonic_pi, name}, 0,
           rate: semitones(note),
           amp: amp,
           sustain: 0.2,
           release: 0.05
         )}
      end

    at(hits, 4)
  end

  # The rate that moves a recording by so many semitones.
  defp semitones(steps), do: :math.pow(2, steps / 12)
end
