defmodule Mx.NotesTest do
  use ExUnit.Case, async: true

  import Mx,
    only: [
      chord: 2,
      scale: 2,
      scale: 3,
      ring: 2,
      intervals: 1,
      melody: 2,
      nearest: 2,
      nearest: 3,
      below: 2,
      voice: 2,
      fit: 2
    ]

  alias Mx.Notes

  test "a note name is the same note as its number" do
    assert Notes.note(:c4) == 60
    assert Notes.note(:C4) == 60
    assert Notes.note(60) == 60
  end

  test "a note name takes a sharp, a flat and an octave, which defaults to 4" do
    assert Notes.note(:fs3) == 54
    assert Notes.note(:eb3) == 51
    assert Notes.note(:a) == 69
    assert Notes.note(:Bb) == 70
  end

  test "an unknown note name is refused, naming it" do
    assert_raise ArgumentError, "unknown note h4", fn -> Notes.note(:h4) end
  end

  test "chords are lists of notes" do
    assert chord(:c4, :major) == [60, 64, 67]
    assert chord(:a3, :minor7) == [57, 60, 64, 67]
    assert chord(60, :major) == chord(:c4, :major)

    for name <- ~w(major minor dim aug dom7 major7 minor7 sus2 sus4)a do
      assert [60 | _] = chord(:c4, name)
    end
  end

  test "chords for choro: diminished, half-diminished, sixths and extended dominants" do
    assert chord(:c4, :dim7) == [60, 63, 66, 69]
    assert chord(:c4, :half_dim7) == [60, 63, 66, 70]
    assert chord(:c4, :major6) == [60, 64, 67, 69]
    assert chord(:c4, :minor6) == [60, 63, 67, 69]
    assert chord(:c4, :dom7_flat9) == [60, 64, 67, 70, 73]
    assert chord(:c4, :dom9) == [60, 64, 67, 70, 74]
    assert_raise ArgumentError, "unknown chord dim9", fn -> chord(:c4, :dim9) end
  end

  test "the harmonic minor scale" do
    assert scale(:a3, :harmonic_minor) == [57, 59, 60, 62, 64, 65, 68, 69]
  end

  test "an unknown chord is refused, naming it" do
    assert_raise ArgumentError, "unknown chord major9th", fn -> chord(:c4, :major9th) end
  end

  test "scales are lists of notes that end on the octave" do
    assert scale(:c4, :major) == [60, 62, 64, 65, 67, 69, 71, 72]

    assert scale(:e3, :minor_pentatonic, octaves: 2) ==
             [52, 55, 57, 59, 62, 64, 67, 69, 71, 74, 76]

    for name <-
          ~w(major minor major_pentatonic minor_pentatonic dorian mixolydian blues chromatic)a do
      notes = scale(:c4, name)
      assert {hd(notes), List.last(notes)} == {60, 72}
    end
  end

  test "an unknown scale is refused, naming it" do
    assert_raise ArgumentError, "unknown scale lydianish", fn -> scale(:c4, :lydianish) end
  end

  test "a scale works with ring" do
    assert ring(scale(:c4, :major), 9) == 62
  end

  test "intervals gives the step from each note to the next, from numbers or names" do
    assert intervals([60, 64, 67]) == [4, 3]
    assert intervals([:c4, :e4, :g4]) == [4, 3]
  end

  test "melody takes steps from a start note, given as a number or a name" do
    assert melody(60, [4, 3, -2]) == [60, 64, 67, 65]
    assert melody(:c4, [4, 3]) == [60, 64, 67]
  end

  test "melody gives back the notes whose intervals it takes, from their first note" do
    assert melody(62, intervals([62, 66, 69])) == [62, 66, 69]
  end

  test "nearest is the closest note of the chord in any octave, the lower on a tie" do
    assert nearest(65, chord(:c4, :major)) == 64
    assert nearest(66, chord(:c4, :major)) == 67
    assert nearest(62, chord(:c4, :major)) == 60
    assert nearest(50, chord(:c4, :major)) == 48
  end

  test "nearest leaves out the note given as except" do
    assert nearest(64, chord(:c4, :major), except: 64) == 67
  end

  test "below is the closest note of the chord strictly below" do
    assert below(76, chord(:a4, :minor7)) == 72
    assert below(72, chord(:a4, :minor7)) == 69
  end

  test "voice places each note of the chord once between from and to" do
    assert voice(chord(:g2, :major6), from: 62, to: 73) == [62, 64, 67, 71]
  end

  test "voice leaves out the root of a chord of more notes than its limit" do
    assert voice(chord(:c4, :dom9), from: 62, to: 73, limit: 4) == [62, 64, 67, 70]
    assert voice(chord(:c4, :major7), from: 62, to: 73, limit: 4) == [64, 67, 71, 72]
  end

  test "voice refuses a range that cannot hold every note of the chord" do
    assert_raise ArgumentError,
                 "voice cannot place every note of [60, 64, 67] from 62 to 66",
                 fn ->
                   voice(chord(:c4, :major), from: 62, to: 66)
                 end
  end

  test "fit bends a scale to a chord, each missing chord tone in place of the note a semitone below" do
    minor = scale(:a4, :minor)
    fitted = fit(minor, chord(:e4, :dom7))
    assert Enum.at(minor, 6) == 79
    assert fitted == List.replace_at(minor, 6, 80)
    assert fit(scale(:c4, :major), chord(:a3, :dom7)) == [61, 62, 64, 65, 67, 69, 71, 73]
  end

  test "fit takes the note a semitone above a missing chord tone when there is none below" do
    pentatonic = scale(:c4, :major_pentatonic)
    assert pentatonic == [60, 62, 64, 67, 69, 72]
    assert fit(pentatonic, [66]) == [60, 62, 64, 66, 69, 72]
    assert fit(pentatonic, [59]) == [59, 62, 64, 67, 69, 71]
  end
end
