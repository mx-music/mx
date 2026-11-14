defmodule ThreeTunings do
  @moduledoc """
  Three Tunings, three short pieces for the African keyed instruments of VCSL, Versilian Studios'
  Versilian Community Sample Library, under Creative Commons 0: the nyunga nyunga of Mozambique, a
  kalimba of Kenya and the mbira mavembe of Zimbabwe, each with keys of metal plucked by the
  thumbs, and the balafon and slit drum beside them.
  Each instrument keeps the tuning it was recorded in, so each piece is in its instrument's own
  scale: the nyunga nyunga's scale of F, the kalimba's five notes of B, and the mavembe's scale of
  G with its flat second.
  The first is in the manner of the nyunga nyunga's songs, the thumbs alternating a bass with the
  notes above it through four chords, while the balafon keeps a figure under it and runs down the
  scale as Mande balafon players do between verses.
  The second is the kalimba in canon with itself over the slit drum.
  The third is built as Shona mbira music is, a cycle of 48 pulses in four phrases of three
  chords, a second mbira playing the same part a pulse later so that the two interlock, with the
  drum's three against the chords' four.
  VCSL names each key an octave below the pitch mx names it by.
  The pack's mbira dzaVadzimu plays in vcsl.exs, and its second kalimba, of Tanzania, is left out.
  The files are fetched as the song loads, about 60 MB.
  """

  use Mx.Song, tempo: 108

  @repo "sgossner/VCSL"
  @commit "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"

  vcsl = fn path -> {:github, @repo, @commit, "Idiophones/#{path}"} end

  # The files of one instrument, each key the start of its name, an octave above that name.
  keys = fn folder, prefix, suffix, names ->
    for name <- names do
      key = name |> String.split("_") |> hd()
      note = key |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      {vcsl.("#{folder}/#{prefix}#{name}#{suffix}.wav"), note: pitch(note) + 12}
    end
  end

  @nyunga keys.(
            "Plucked Idiophones/Nyunga Nyunga, Mozambique, Low F",
            "Mbira2_Normal_MainSpirit_",
            "_vl3_rr2",
            ~w(F2_k11 A2_k9 A#2_k13 D3_k17 E3_k19 F3_k5 G3_k3 A3_k1 A#3_k12 C4_k14 D4_k16 E4_k18 F4_k10)
          ) ++
            keys.(
              "Plucked Idiophones/Nyunga Nyunga, Mozambique, Low F",
              "Mbira2_Normal_MainSpirit_",
              "_vl3_rr3",
              ~w(C3_k15)
            )

  @kalimba keys.(
             "Plucked Idiophones/Kalimba, Kenya",
             "Mbira6_Normal_MainSpirit_",
             "_vl3_rr2",
             ~w(B2_k8 C#3_k7 D#3_k9 F#3_k10 G#3_k11 B3_k12 C#4_k2 D#4_k13 F#4_k14)
           )

  @mavembe keys.(
             "Plucked Idiophones/Mbira Mavembe (Gandanga), Zimbabwe, Low G",
             "Mbira5_Normal_MainSpirit_",
             "_vl2_rr1",
             ~w(A#1_k12 C2_k10 D2_k8 D#2_k6 F2_k4 G2_k13 G#2_k2 A#2_k15 C3_k9 D3_k11 D#3_k7 F3_k5 G3_k16 G#3_k17 A#3_k18 C4_k19 D4_k20 D#4_k21 F4_k22)
           )

  @balafon keys.(
             "Struck Idiophones/Balafon/Traditional Mallet",
             "EthnicXylo_tradM_",
             "_vl3_rr1_Mid",
             ~w(C#3 F3 C4 F4 C5 F5)
           )

  @low_drum vcsl.("Struck Idiophones/Slit Drum/LogDrumLo_MedM_v3_rr1_Sum.wav")
  @high_drum vcsl.("Struck Idiophones/Slit Drum/LogDrumHi_MedM_v3_rr1_Sum.wav")

  @room [room: 0.6, mix: 0.2]
  @ringing [sustain: 2, release: 1.5]

  part :nyunga,
    synth: sampled(@nyunga),
    defaults: @ringing,
    fx: [level: [amp: 0.55], reverb: @room, pan: [pan: -0.25]]

  part :second_nyunga,
    synth: sampled(@nyunga),
    defaults: @ringing,
    fx: [level: [amp: 0.7], reverb: @room, pan: [pan: 0.3]]

  part :kalimba,
    synth: sampled(@kalimba),
    defaults: @ringing,
    fx: [level: [amp: 2.0], reverb: @room, pan: [pan: -0.3]]

  part :second_kalimba,
    synth: sampled(@kalimba),
    defaults: @ringing,
    fx: [level: [amp: 1.3], reverb: @room, pan: [pan: 0.3]]

  part :mavembe,
    synth: sampled(@mavembe),
    defaults: @ringing,
    fx: [level: [amp: 0.55], reverb: @room, pan: [pan: -0.3]]

  part :second_mavembe,
    synth: sampled(@mavembe),
    defaults: @ringing,
    fx: [level: [amp: 0.48], reverb: @room, pan: [pan: 0.3]]

  part :balafon,
    synth: sampled(@balafon),
    defaults: [sustain: 1, release: 0.5],
    fx: [level: [amp: 1.6], reverb: @room, pan: [pan: 0.1]]

  part :drum, fx: [level: [amp: 2.4], reverb: @room]

  # A third of a beat, the pulse of the first and third pieces.
  @pulse 1 / 3

  # The nyunga nyunga's four chords, each as its two bass notes and the three notes above them.
  @song [
    {[:f3, :c4], [:a4, :c5, :f5]},
    {[:bb3, :d4], [:bb4, :d5, :f5]},
    {[:f3, :a3], [:c5, :f5, :a4]},
    {[:c4, :e4], [:g4, :c5, :e5]}
  ]

  # The kalimba's four bars, in eighth notes.
  @round [
    ~w(b3 fs4 b4 ds5 cs5 b4 gs4 fs4)a,
    ~w(cs4 gs4 cs5 fs5 ds5 cs5 b4 gs4)a,
    ~w(ds4 fs4 b4 ds5 fs5 ds5 b4 fs4)a,
    ~w(cs4 fs4 gs4 cs5 b4 gs4 fs4 ds4)a
  ]

  # The mavembe's twelve chords as their roots, four phrases of three.
  @cycle ~w(eb3 g3 bb2 eb3 g3 c3 eb3 ab3 c3 f3 ab3 c3)a

  def song do
    seq([first(), rest(2), second(), rest(2), third()])
  end

  defp first do
    seq([
      play(nyunga: thumbs(1)),
      play(nyunga: thumbs(1), balafon: figure(1), drum: drum("L.....l..l..", 4)),
      play(
        nyunga: thumbs(2),
        second_nyunga: tune(2),
        balafon: figure(2),
        drum: drum("L.....l..l..", 8)
      ),
      play(nyunga: note([:f3, :c4, :a4, :f5], 4, strum: 0.05), balafon: note([:f4, :f5], 4))
    ])
  end

  # The kalimba alone, then with itself two beats later, the slit drum on every other beat.
  defp second do
    seq([
      play(kalimba: canon(1)),
      play(
        kalimba: seq([canon(2), note([:b3, :fs4, :b4], 4, strum: 0.08)]),
        second_kalimba: seq([rest(2), canon(2), note([:ds5, :fs5], 2)]),
        drum: drum("H.....h.....", 9)
      )
    ])
  end

  # One mbira, then two, the balafon and the drum joining after the second time round.
  defp third do
    seq([
      play(mavembe: cycle(1)),
      play(
        mavembe: seq([cycle(3), note([:eb3, :bb3, :eb4, :g4], 4, strum: 0.06)]),
        second_mavembe: seq([rest(@pulse), cycle(3)]),
        balafon: seq([rest(16), roots(1), together([roots(1), above()]), note([:eb4, :eb5], 4)]),
        drum: seq([rest(16), drum("H..h..h..h..", 8)])
      )
    ])
  end

  defp play(voices) do
    together(for {name, music} <- voices, do: part(name, music))
  end

  # The thumbs' part: a bass note on every third pulse and the upper notes between.
  defp thumbs(times) do
    repeat(
      seq(
        for {[low, high], [first, second, third]} <- @song do
          pulses([
            low,
            first,
            second,
            high,
            third,
            second,
            low,
            first,
            second,
            high,
            third,
            second
          ])
        end
      ),
      times
    )
  end

  # The balafon's figure on each chord, and in the last bar of each four a run down the scale.
  defp figure(times) do
    bars =
      for {{[low, _high], [_first, _second, _third]}, index} <- Enum.with_index(@song) do
        root = pitch(low)

        if index == 3 do
          pulses(~w(f6 e6 d6 c6 bb5 a5 g5 f5 e5 d5 c5 g4)a)
        else
          pulses(
            [
              root,
              nil,
              root + 7,
              root + 12,
              nil,
              root + 16,
              root,
              nil,
              root + 7,
              root + 12,
              nil,
              root + 16
            ],
            0.8
          )
        end
      end

    repeat(seq(bars), times)
  end

  # The slit drum at the pulses given of so many, l the low drum and h the high one.
  defp drum(pattern, times) do
    hits =
      for {cell, index} <- Enum.with_index(String.graphemes(pattern)), cell != "." do
        file = if cell in ["l", "L"], do: @low_drum, else: @high_drum
        amp = if cell in ["L", "H"], do: 1.0, else: 0.6
        {index * @pulse, sample(file, 0, amp: amp)}
      end

    repeat(at(hits, String.length(pattern) * @pulse), times)
  end

  # The tune over it, a note to each three pulses.
  defp tune(times) do
    notes = ~w(f5 e5 f5 c5 d5 c5 d5 bb4 c5 a4 c5 f5 e5 d5 e5 c5)a
    repeat(seq(for name <- notes, do: note(name, 1)), times)
  end

  defp canon(times) do
    repeat(seq(for name <- List.flatten(@round), do: note(name, 0.5)), times)
  end

  # A chord in four pulses: its root, the fifth above the octave, the octave, and the fifth.
  defp cycle(times) do
    repeat(
      seq(
        for name <- @cycle do
          root = pitch(name)
          pulses([root, root + 19, root + 12, root + 7])
        end
      ),
      times
    )
  end

  # The balafon under the mbiras, a note to each chord, and then a line above them.
  defp roots(times) do
    repeat(seq(for name <- @cycle, do: note(pitch(name) + 12, 4 * @pulse)), times)
  end

  defp above do
    notes = ~w(g5 f5 eb5 g5 f5 eb5 g5 ab5 g5 f5 eb5 d5)a
    seq(for name <- notes, do: seq([rest(2 * @pulse), note(name, 2 * @pulse)]))
  end

  # Notes a pulse apart, nil a silent pulse.
  defp pulses(notes, amp \\ 1.0) do
    seq(for name <- notes, do: if(name, do: note(name, @pulse, amp: amp), else: rest(@pulse)))
  end
end
