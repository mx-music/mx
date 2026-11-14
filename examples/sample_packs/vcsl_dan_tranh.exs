defmodule DanTranh do
  @moduledoc """
  A solo for the dan tranh, the Vietnamese zither of sixteen strings, in VCSL, Versilian Studios'
  Versilian Community Sample Library, under Creative Commons 0.
  The instrument is tuned to five notes, here B, C sharp, D sharp, F sharp and G sharp, and was
  recorded on every string plucked, plucked with vibrato from the left hand, and in tremolo, with
  sweeps across all the strings.
  The solo is shaped as a dan tranh piece is: a prelude without a beat, of sweeps and long notes,
  and then a tune in the five notes, its first note of each phrase doubled at the octave and its
  long notes given vibrato, over the thumb on the low strings.
  The tune goes round once more with its longer notes in tremolo, and a sweep down the strings
  ends it.
  VCSL names each string an octave below the pitch mx names it by.
  The files are fetched as the song loads, about 50 MB.
  """

  use Mx.Song, tempo: 84

  @folder "Chordophones/Zithers/Dan Tranh"

  vcsl = fn path -> {:vcsl, "#{@folder}/#{path}"} end

  # Every string recorded one way, an octave above its name.
  strings = fn way, suffix ->
    for name <- ~w(B1 C#2 D#2 F#2 G#2 B2 C#3 D#3 F#3 G#3 B3 C#4 D#4 F#4 G#4 B4) do
      note = name |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      {vcsl.("#{way}/#{name}#{suffix}.wav"), note: pitch(note) + 12}
    end
  end

  @plucked strings.("Normal", "_ff_1")
  @vibrato strings.("Vibrato", "_vib_ff_1")
  @tremolo strings.("Tremolo", "_Trem_1")

  @sweep_up vcsl.("Gliss/Gliss_Up_Swl_ff_1.wav")
  @sweep_down vcsl.("Gliss/Gliss_Dwn_Slw_mf_2.wav")

  @room [room: 0.75, mix: 0.3]

  part :plucked,
    synth: sampled(@plucked),
    defaults: [sustain: 2, release: 1.5],
    fx: [level: [amp: 2.6], reverb: @room]

  part :thumb,
    synth: sampled(@plucked),
    defaults: [sustain: 3, release: 2],
    fx: [level: [amp: 3.0], reverb: @room, pan: [pan: -0.2]]

  part :vibrato,
    synth: sampled(@vibrato),
    defaults: [sustain: 3, release: 2],
    fx: [level: [amp: 2.6], reverb: @room]

  part :tremolo,
    synth: sampled(@tremolo),
    defaults: [attack: 0.02, release: 0.4],
    fx: [level: [amp: 2.5], reverb: @room]

  part :sweeps, fx: [level: [amp: 2.2], reverb: @room]

  # The tune's two halves, each two phrases of eight beats, as notes and their lengths in eighth
  # notes.
  @first [
    [b4: 2, ds5: 1, fs5: 1, gs5: 2, fs5: 2, ds5: 1, fs5: 1, ds5: 1, cs5: 1, b4: 4],
    [gs4: 2, b4: 1, cs5: 1, ds5: 2, cs5: 2, b4: 1, gs4: 1, fs4: 1, gs4: 1, b4: 4]
  ]
  @second [
    [fs5: 2, gs5: 1, fs5: 1, ds5: 2, fs5: 2, gs5: 1, fs5: 1, ds5: 1, cs5: 1, ds5: 4],
    [cs5: 2, ds5: 1, cs5: 1, b4: 2, gs4: 2, fs4: 1, gs4: 1, b4: 1, cs5: 1, b4: 4]
  ]

  def song do
    seq([
      prelude(),
      verse(@first, 4, :vibrato),
      verse(@first, 4, :vibrato),
      verse(@second, 4, :vibrato),
      verse(@first, 4, :vibrato),
      verse(@first, 2, :tremolo),
      verse(@second, 2, :tremolo),
      ending()
    ])
  end

  # The prelude, without a beat: a sweep up the strings, long notes with vibrato, two in tremolo,
  # and a sweep down.
  defp prelude do
    play(
      sweeps: at([{0, sample(@sweep_up, 8)}, {24, sample(@sweep_down, 8, amp: 1.5)}], 31),
      vibrato:
        at(
          [
            {6, note(:b3, 3)},
            {9, note(:fs4, 2)},
            {11, note(:gs4, 1)},
            {12, note([:b2, :b4], 4, strum: 0.1)},
            {21, note(:b4, 3)}
          ],
          31
        ),
      tremolo: at([{16, note(:ds5, 3)}, {19, note(:cs5, 2)}], 31)
    )
  end

  defp verse(phrases, long, way) do
    play([{:thumb, thumb(phrases)} | tune(phrases, long, way)])
  end

  # The last notes, and the sweep down under them.
  defp ending do
    play(
      sweeps: sample(@sweep_down, 12, amp: 1.5),
      vibrato: seq([rest(6), note([:b2, :fs3, :b3, :b4], 6, strum: 0.12, sustain: 6, release: 3)])
    )
  end

  defp play(voices) do
    together(for {name, music} <- voices, do: part(name, music))
  end

  # The thumb on the low strings, on the first beat of each bar and a quieter fifth on the third.
  defp thumb(phrases) do
    seq(for _ <- phrases, _ <- 1..2, do: seq([note(:b2, 2), note(:fs3, 2, amp: 0.6)]))
  end

  # The phrases played one way: the notes of at least so many eighths on the part given, the first
  # of each phrase with its lower octave, and the rest plucked.
  defp tune(phrases, long, way) do
    for voice <- [:plucked, way] do
      music =
        for phrase <- phrases, {{name, eighths}, index} <- Enum.with_index(phrase) do
          mine = if eighths >= long, do: way, else: :plucked

          first =
            if index == 0, do: note([pitch(name) - 12, pitch(name)], eighths / 2, strum: 0.04)

          if mine == voice, do: first || note(name, eighths / 2), else: rest(eighths / 2)
        end

      {voice, seq(music)}
    end
  end
end
