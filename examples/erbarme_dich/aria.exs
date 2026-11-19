defmodule Aria do
  @moduledoc """
  Erbarme dich, imported from bwv244.39.mxl by mix mx.import.
  Each part's bars are written one to a line where they fit, as the bar's number and its music; a
  bar of several voices plays them together.
  A note's length is in beats, a quarter note being a beat; a note tied over a bar line sounds for
  the whole tie, given as its sustain, and the note it ties into is a rest.
  Notes play at vel 0.6, and a dynamic marked in the score gives the notes after it another vel.
  The whole score plays once, 276.5 beats.
  """

  use Mx.Song, tempo: 48

  part :violin, synth: :violin
  part :alto, synth: :oboe
  part :organo_a_canne, synth: :organ

  def song do
    together([
      part(:violin, seq(Enum.map(order(), &bar(:violin, &1)))),
      part(:alto, seq(Enum.map(order(), &bar(:alto, &1)))),
      part(:organo_a_canne, seq(Enum.map(order(), &bar(:organo_a_canne, &1))))
    ])
  end

  # The bars in the order the score plays them, its repeats taken.
  defp order, do: Enum.concat([0..46])

  defp bar(:violin, 0), do: seq(fs4: 0.5)

  defp bar(:violin, 1) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5),
      note(:b4, 0.75),
      note(:as4, 0.25),
      note(:b4, 0.5),
      note(:b4, 1.5, sustain: 2.5),
      rest(1),
      note(:b4, 0.5)
    ])
  end

  defp bar(:violin, 2) do
    seq([
      note(:g5, 0.75),
      note(:fs5, 0.125),
      note(:g5, 0.125),
      note(:a5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:g5, 0.25),
      note(:fs5, 0.5),
      note(:e5, 1.5, sustain: 2.25),
      rest(0.75),
      note(:g5, 0.25),
      note(:e5, 0.5)
    ])
  end

  defp bar(:violin, 3) do
    seq([
      note(:c5, 0.75),
      note(:g5, 0.25),
      note(:e5, 0.5),
      note(:b4, 0.75),
      note(:g5, 0.25),
      note(:e5, 0.5),
      note(:as4, 0.75),
      note(:e5, 0.125),
      note(:fs5, 0.125),
      note(:g5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:fs5, 0.25),
      note(:e5, 0.5)
    ])
  end

  defp bar(:violin, 4) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.125),
      note(:d5, 0.125),
      note(:e5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:d5, 0.25),
      note(:cs5, 0.5),
      note(:as4, 1.5),
      note(:as4, 0.75),
      note(:fs4, 0.25),
      note(:as4, 0.25),
      note(:cs5, 0.25)
    ])
  end

  defp bar(:violin, 5) do
    seq(
      e5: 0.125,
      d5: 0.125,
      cs5: 0.25,
      b4: 0.5,
      as4: 0.25,
      b4: 0.25,
      cs5: 0.125,
      b4: 0.125,
      as4: 0.25,
      g4: 0.5,
      fs4: 0.25,
      g4: 0.25,
      g4: 0.125,
      fs4: 0.125,
      e4: 0.25,
      as4: 0.75,
      g4: 0.125,
      fs4: 0.125,
      g4: 0.125,
      fs4: 0.125,
      e4: 0.25,
      cs5: 0.75,
      fs4: 0.125,
      e4: 0.125
    )
  end

  defp bar(:violin, 6) do
    seq(
      fs4: 0.125,
      e4: 0.125,
      ds4: 0.25,
      c4: 0.5,
      b3: 0.25,
      a4: 0.125,
      g4: 0.125,
      a4: 0.125,
      g4: 0.125,
      fs4: 0.25,
      e4: 0.5,
      ds4: 0.25,
      c5: 0.125,
      b4: 0.125,
      c5: 0.125,
      b4: 0.125,
      a4: 0.25,
      g4: 0.5,
      fs4: 0.25,
      fs5: 0.125,
      e5: 0.125,
      fs5: 0.125,
      e5: 0.125,
      ds5: 0.25,
      c5: 0.5,
      b4: 0.25,
      fs5: 0.25
    )
  end

  defp bar(:violin, 7) do
    seq(
      g5: 0.125,
      a5: 0.125,
      b5: 0.5,
      a5: 0.125,
      g5: 0.125,
      a5: 0.125,
      g5: 0.125,
      fs5: 0.25,
      e5: 0.125,
      fs5: 0.125,
      g5: 0.5,
      fs5: 0.125,
      e5: 0.125,
      fs5: 0.125,
      e5: 0.125,
      d5: 0.25,
      c5: 0.125,
      d5: 0.125,
      e5: 0.5,
      d5: 0.125,
      c5: 0.125,
      d5: 0.125,
      c5: 0.125,
      b4: 0.25,
      as4: 0.125,
      b4: 0.125,
      cs5: 0.5,
      b4: 0.125,
      as4: 0.125,
      b4: 0.125,
      as4: 0.125,
      gs4: 0.25
    )
  end

  defp bar(:violin, 8) do
    seq([
      note(:fs4, 0.75),
      note(:gs4, 0.125),
      note(:as4, 0.125),
      note(:b4, 0.125),
      note(:cs5, 0.125),
      note(:d5, 0.125),
      note(:cs5, 0.125),
      note(:e5, 0.5),
      note(:d5, 0.5),
      note(:cs5, 0.5),
      note(:b4, 1.5, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 9), do: seq(r: 3, r: 1, r: 0.5, r: 0.5, r: 0.5, b4: 0.5)

  defp bar(:violin, 10) do
    seq([
      note(:g5, 0.75),
      note(:fs5, 0.125),
      note(:g5, 0.125),
      note(:a5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:g5, 0.25),
      note(:fs5, 0.5),
      note(:e5, 1.5),
      note(:e5, 0.75),
      note(:g5, 0.25),
      note(:e5, 0.5)
    ])
  end

  defp bar(:violin, 11) do
    seq([
      note(:c5, 0.75),
      note(:g5, 0.25),
      note(:e5, 0.5),
      note(:b4, 0.75),
      note(:g5, 0.25),
      note(:e5, 0.5),
      note(:as4, 0.75),
      note(:e5, 0.125),
      note(:fs5, 0.125),
      note(:g5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:fs5, 0.25),
      note(:e5, 0.5)
    ])
  end

  defp bar(:violin, 12) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.125),
      note(:d5, 0.125),
      note(:e5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:d5, 0.25),
      note(:cs5, 0.5),
      note(:as4, 1.5, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 13) do
    seq(r: 1, r: 0.5, r: 1, r: 0.5, r: 0.5, r: 0.25, e5: 0.25, b4: 0.5, g4: 1, r: 0.5)
  end

  defp bar(:violin, 14) do
    seq(r: 1, r: 0.5, r: 1, r: 0.5, r: 0.5, r: 0.25, fs5: 0.25, cs5: 0.5, a4: 1, cs5: 0.5)
  end

  defp bar(:violin, 15) do
    seq([
      note(:a5, 0.75),
      note(:gs5, 0.25),
      note(:fs5, 0.5),
      note(:fs5, 0.75),
      note(:es5, 0.25),
      note(:fs5, 0.5),
      note(:fs5, 3, sustain: 4)
    ])
  end

  defp bar(:violin, 16) do
    seq([
      rest(1),
      note(:b4, 0.5),
      note(:b4, 0.5),
      note(:as4, 0.5),
      note(:e5, 0.5, sustain: 1),
      rest(0.5),
      note(:d5, 0.25),
      note(:fs5, 0.25),
      note(:cs5, 0.5, sustain: 1),
      rest(0.5),
      note(:b4, 0.25),
      note(:d5, 0.25),
      note(:a4, 0.5)
    ])
  end

  defp bar(:violin, 17) do
    seq([
      note(:g4, 0.75),
      note(:d5, 0.25),
      note(:b4, 0.5),
      note(:fs4, 0.75),
      note(:d5, 0.25),
      note(:b4, 0.5),
      note(:es4, 0.75),
      note(:b4, 0.125),
      note(:cs5, 0.125),
      note(:d5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5)
    ])
  end

  defp bar(:violin, 18) do
    seq([
      note(:a4, 0.75),
      note(:gs4, 0.125),
      note(:a4, 0.125),
      note(:b4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:a4, 0.25),
      note(:gs4, 0.5),
      note(:es4, 1.5, sustain: 1.75),
      rest(0.25),
      note(:fs4, 0.25),
      note(:gs4, 0.25),
      note(:cs5, 0.25),
      note(:es5, 0.25),
      note(:gs5, 0.25)
    ])
  end

  defp bar(:violin, 19) do
    seq([
      note(:b5, 0.125),
      note(:a5, 0.125),
      note(:gs5, 0.25),
      note(:fs5, 0.5),
      note(:es5, 0.375),
      note(:fs5, 0.125),
      note(:gs5, 0.125),
      note(:fs5, 0.125),
      note(:es5, 0.25),
      note(:d5, 0.5),
      note(:cs5, 0.375),
      note(:d5, 0.125),
      note(:es5, 1.5, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 20) do
    seq([
      note(:e5, 0.125),
      note(:d5, 0.125),
      note(:cs5, 0.25),
      note(:b4, 0.5),
      note(:as4, 0.375),
      note(:b4, 0.125),
      note(:cs5, 0.125),
      note(:b4, 0.125),
      note(:as4, 0.25),
      note(:g4, 0.5),
      note(:fs4, 0.375),
      note(:g4, 0.125),
      note(:as4, 1.5, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 21) do
    seq(
      d5: 0.125,
      e5: 0.125,
      fs5: 0.5,
      e5: 0.125,
      d5: 0.125,
      e5: 0.125,
      d5: 0.125,
      cs5: 0.25,
      b4: 0.125,
      cs5: 0.125,
      d5: 0.5,
      cs5: 0.125,
      b4: 0.125,
      cs5: 0.125,
      b4: 0.125,
      as4: 0.25,
      g4: 0.125,
      a4: 0.125,
      b4: 0.5,
      a4: 0.125,
      g4: 0.125,
      a4: 0.125,
      g4: 0.125,
      fs4: 0.25,
      es4: 0.125,
      fs4: 0.125,
      gs4: 0.5,
      fs4: 0.125,
      es4: 0.125,
      fs4: 0.125,
      es4: 0.125,
      ds4: 0.25
    )
  end

  defp bar(:violin, 22) do
    seq([
      note(:cs4, 0.5),
      rest(0.5),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(0.5),
      rest(0.5),
      note(:cs5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 23) do
    seq([
      note(:a5, 0.75, vel: 0.8),
      note(:gs5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8),
      note(:fs5, 0.75, vel: 0.8),
      note(:es5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8),
      note(:fs5, 1.5, vel: 0.8, sustain: 2.5),
      rest(1),
      note(:fs5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 24) do
    seq([
      note(:d6, 0.75, vel: 0.8),
      note(:cs6, 0.125, vel: 0.8),
      note(:d6, 0.125, vel: 0.8),
      note(:e6, 0.5, vel: 0.8),
      note(:e6, 0.75, vel: 0.8),
      note(:d6, 0.25, vel: 0.8),
      note(:cs6, 0.5, vel: 0.8),
      note(:b5, 1.5, vel: 0.8, sustain: 2.25),
      rest(0.75),
      note(:d6, 0.25, vel: 0.8),
      note(:b5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 25) do
    seq([
      note(:g5, 0.75, vel: 0.8),
      note(:d6, 0.25, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:fs5, 0.75, vel: 0.8),
      note(:d6, 0.25, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:es5, 0.75, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:d5, 0.75, vel: 0.8),
      note(:cs5, 0.25, vel: 0.8),
      note(:b4, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 26) do
    seq([
      note(:cs5, 0.75, vel: 0.8),
      note(:ds5, 0.125, vel: 0.8),
      note(:es5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:a5, 0.5, vel: 0.8),
      note(:gs5, 0.5, vel: 0.8),
      note(:fs5, 1.5, vel: 0.8, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 27) do
    seq([
      rest(0.5),
      rest(0.25),
      note(:c6, 0.25, vel: 0.8),
      note(:a5, 0.5, vel: 0.8),
      note(:e5, 0.75, vel: 0.8),
      note(:c6, 0.25, vel: 0.8),
      note(:a5, 0.5, vel: 0.8),
      note(:ds5, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 28) do
    seq([
      rest(0.5),
      rest(0.25),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:c5, 0.75, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:as4, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 29) do
    seq([
      rest(0.5),
      rest(0.25),
      note(:d6, 0.25, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:g5, 0.75, vel: 0.8),
      note(:d6, 0.25, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:es5, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 30) do
    seq([
      note(:a5, 0.125, vel: 0.8),
      note(:b5, 0.125, vel: 0.8),
      note(:cs6, 0.5, vel: 0.8),
      note(:b5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:b5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:gs5, 0.25, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:a5, 0.5, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:e5, 0.25, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:ds5, 0.125, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:ds5, 0.125, vel: 0.8),
      note(:cs5, 0.25, vel: 0.8),
      note(:bs4, 0.5, vel: 0.8),
      rest(0.5),
      rest(0.5)
    ])
  end

  defp bar(:violin, 31) do
    seq([
      rest(1),
      rest(0.5),
      rest(0.5),
      rest(0.25),
      note(:a5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8),
      note(:d5, 0.75, vel: 0.8),
      note(:a5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8),
      note(:cs5, 0.75, vel: 0.8),
      note(:a5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 32) do
    seq([
      note(:bs4, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(1),
      note(:cs5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 33) do
    seq([
      note(:a5, 0.75, vel: 0.8),
      note(:gs5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:b5, 0.75, vel: 0.8),
      note(:a5, 0.25, vel: 0.8),
      note(:gs5, 0.5, vel: 0.8),
      note(:fs5, 3, vel: 0.8, sustain: 6.75)
    ])
  end

  defp bar(:violin, 34) do
    seq([
      rest(3),
      rest(0.75),
      note(:b5, 0.25, vel: 0.8),
      note(:g5, 0.5, vel: 0.8),
      note(:b4, 0.75, vel: 0.8),
      note(:a5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 35) do
    seq([
      note(:g4, 0.75, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:b4, 0.75, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:as4, 0.75, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:g5, 0.5, vel: 0.8, sustain: 1.25),
      rest(0.75),
      note(:fs5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 36) do
    seq([
      note(:d5, 0.75, vel: 0.8),
      note(:cs5, 0.125, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:e5, 0.5, vel: 0.8, sustain: 1.25),
      rest(0.75),
      note(:d5, 0.25, vel: 0.8),
      note(:cs5, 0.5, vel: 0.8),
      note(:as4, 1.5, vel: 0.8, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 37) do
    seq([
      rest(3),
      rest(0.5),
      rest(0.25),
      note(:e5, 0.25, vel: 0.8),
      note(:b4, 0.5, vel: 0.8),
      note(:g4, 1, vel: 0.8),
      rest(0.5)
    ])
  end

  defp bar(:violin, 38) do
    seq([
      rest(3),
      rest(0.5),
      rest(0.25),
      note(:b4, 0.25, vel: 0.8),
      note(:fs4, 0.5, vel: 0.8),
      note(:d4, 1, vel: 0.8),
      note(:fs4, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 39) do
    seq([
      note(:d5, 0.75, vel: 0.8),
      note(:cs5, 0.25, vel: 0.8),
      note(:b4, 0.5, vel: 0.8),
      note(:b4, 0.75, vel: 0.8),
      note(:as4, 0.25, vel: 0.8),
      note(:b4, 0.5, vel: 0.8),
      note(:b4, 3, vel: 0.8, sustain: 4)
    ])
  end

  defp bar(:violin, 40) do
    seq([
      rest(1),
      note(:e5, 0.5, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:ds5, 0.5, vel: 0.8),
      note(:a5, 0.5, vel: 0.8, sustain: 1),
      rest(0.5),
      note(:g5, 0.25, vel: 0.8),
      note(:a5, 0.25, vel: 0.8),
      note(:fs5, 0.5, vel: 0.8, sustain: 1),
      rest(0.5),
      note(:e5, 0.25, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:d5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 41) do
    seq([
      note(:c5, 0.75, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:b4, 0.75, vel: 0.8),
      note(:g5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:as4, 0.75, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:g5, 0.5, vel: 0.8, sustain: 1.25),
      rest(0.75),
      note(:fs5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8)
    ])
  end

  defp bar(:violin, 42) do
    seq([
      note(:d5, 0.75, vel: 0.8),
      note(:cs5, 0.125, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:e5, 0.5, vel: 0.8, sustain: 1.25),
      rest(0.75),
      note(:d5, 0.25, vel: 0.8),
      note(:cs5, 0.5, vel: 0.8),
      note(:as4, 1.5, vel: 0.8, sustain: 1.75),
      rest(0.25),
      note(:cs4, 0.25, vel: 0.8),
      note(:fs4, 0.25, vel: 0.8),
      note(:as4, 0.25, vel: 0.8),
      note(:cs5, 0.25, vel: 0.8),
      note(:d5, 0.25, vel: 0.8)
    ])
  end

  defp bar(:violin, 43) do
    seq([
      note(:e5, 0.125, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:cs5, 0.25, vel: 0.8),
      note(:b4, 0.5, vel: 0.8),
      note(:as4, 0.375, vel: 0.8),
      note(:b4, 0.125, vel: 0.8),
      note(:cs5, 0.125, vel: 0.8),
      note(:b4, 0.125, vel: 0.8),
      note(:as4, 0.25, vel: 0.8),
      note(:g4, 0.5, vel: 0.8),
      note(:fs4, 0.375, vel: 0.8),
      note(:g4, 0.125, vel: 0.8),
      note(:as4, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 44) do
    seq([
      note(:a5, 0.125, vel: 0.8),
      note(:g5, 0.125, vel: 0.8),
      note(:fs5, 0.25, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:ds5, 0.375, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:ds5, 0.25, vel: 0.8),
      note(:c5, 0.5, vel: 0.8),
      note(:b4, 0.375, vel: 0.8),
      note(:c5, 0.125, vel: 0.8),
      note(:ds5, 1, vel: 0.8),
      rest(0.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:violin, 45) do
    seq([
      note(:g5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:b5, 0.5, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:g5, 0.125, vel: 0.8),
      note(:a5, 0.125, vel: 0.8),
      note(:g5, 0.125, vel: 0.8),
      note(:fs5, 0.25, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:g5, 0.5, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:fs5, 0.125, vel: 0.8),
      note(:e5, 0.125, vel: 0.8),
      note(:d5, 0.25, vel: 0.8),
      note(:c5, 0.125, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:e5, 0.5, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:c5, 0.125, vel: 0.8),
      note(:d5, 0.125, vel: 0.8),
      note(:c5, 0.125, vel: 0.8),
      note(:b4, 0.25, vel: 0.8),
      note(:as4, 0.125, vel: 0.8),
      note(:b4, 0.125, vel: 0.8),
      note(:cs5, 0.5, vel: 0.8),
      note(:b4, 0.125, vel: 0.8),
      note(:as4, 0.125, vel: 0.8),
      note(:b4, 0.125, vel: 0.8),
      note(:as4, 0.125, vel: 0.8),
      note(:gs4, 0.25, vel: 0.8)
    ])
  end

  defp bar(:violin, 46) do
    seq([
      note(:fs4, 0.5, vel: 0.8),
      rest(0.5),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(1),
      rest(0.5),
      rest(1),
      note(:fs4, 0.5, vel: 0.8)
    ])
  end

  defp bar(:alto, 0), do: seq(r: 0.5)
  defp bar(:alto, 1), do: seq(r: 6)
  defp bar(:alto, 2), do: seq(r: 6)
  defp bar(:alto, 3), do: seq(r: 6)
  defp bar(:alto, 4), do: seq(r: 6)
  defp bar(:alto, 5), do: seq(r: 6)
  defp bar(:alto, 6), do: seq(r: 6)
  defp bar(:alto, 7), do: seq(r: 6)
  defp bar(:alto, 8), do: seq(r: 3, r: 1, r: 0.5, r: 0.5, r: 0.5, fs4: 0.5)

  defp bar(:alto, 9) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:as4, 0.25),
      note(:b4, 0.5),
      note(:b4, 3)
    ])
  end

  defp bar(:alto, 10) do
    seq(b4: 1, e4: 0.5, e4: 0.5, ds4: 0.5, a4: 0.5, g4: 1, fs4: 0.5, g4: 1, b4: 0.5)
  end

  defp bar(:alto, 11) do
    seq([
      note(:c5, 1),
      note(:b4, 0.5),
      note(:b4, 1),
      note(:as4, 0.5),
      note(:as4, 1),
      note(:b4, 0.5),
      note(:cs5, 1.5, sustain: 2.25)
    ])
  end

  defp bar(:alto, 12) do
    seq(
      r: 0.75,
      as4: 0.25,
      b4: 0.5,
      cs5: 0.25,
      d5: 0.25,
      e5: 0.5,
      cs5: 0.5,
      as4: 1,
      gs4: 0.5,
      fs4: 1,
      e4: 0.5
    )
  end

  defp bar(:alto, 13) do
    seq([
      note(:ds4, 0.5),
      note(:fs4, 0.25),
      note(:a4, 0.25),
      note(:c5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:b4, 0.25),
      note(:a4, 0.5),
      note(:g4, 1.5, sustain: 2.5),
      rest(1),
      note(:fs4, 0.5)
    ])
  end

  defp bar(:alto, 14) do
    seq([
      note(:f4, 0.5),
      note(:gs4, 0.25),
      note(:b4, 0.25),
      note(:d5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5),
      note(:a4, 1),
      note(:gs4, 0.5),
      note(:a4, 0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5)
    ])
  end

  defp bar(:alto, 15) do
    seq([
      note(:cs5, 3, sustain: 3.75),
      rest(0.75),
      note(:b4, 0.25),
      note(:as4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:b4, 0.25),
      note(:cs5, 0.5)
    ])
  end

  defp bar(:alto, 16) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.125),
      note(:d5, 0.125),
      note(:e5, 0.5),
      note(:e5, 0.75),
      note(:d5, 0.25),
      note(:cs5, 0.5),
      note(:b4, 1.5, sustain: 2.5),
      rest(1),
      note(:a4, 0.5)
    ])
  end

  defp bar(:alto, 17) do
    seq([
      note(:g4, 1),
      note(:fs4, 0.5),
      note(:fs4, 1),
      note(:es4, 0.5),
      note(:es4, 0.75),
      note(:b4, 0.125),
      note(:cs5, 0.125),
      note(:d5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5)
    ])
  end

  defp bar(:alto, 18) do
    seq([
      note(:a4, 0.75),
      note(:gs4, 0.25),
      note(:b4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:a4, 0.25),
      note(:gs4, 0.5),
      note(:es4, 1),
      note(:ds4, 0.5),
      note(:cs4, 1),
      rest(0.5)
    ])
  end

  defp bar(:alto, 19) do
    seq([
      rest(1),
      rest(0.5),
      rest(0.5),
      rest(0.25),
      note(:cs4, 0.25),
      note(:es4, 0.25),
      note(:gs4, 0.25),
      note(:b4, 0.75),
      note(:cs5, 0.25),
      note(:d5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5)
    ])
  end

  defp bar(:alto, 20) do
    seq([
      note(:as4, 1),
      note(:cs5, 0.5),
      note(:e5, 0.75),
      note(:cs5, 0.25),
      note(:as4, 0.25),
      note(:b4, 0.25),
      note(:e4, 0.75),
      note(:fs4, 0.25),
      note(:g4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:fs4, 0.25),
      note(:e4, 0.5)
    ])
  end

  defp bar(:alto, 21) do
    seq([
      note(:d4, 0.5),
      note(:e4, 0.5),
      note(:fs4, 0.5, sustain: 1),
      rest(0.5),
      note(:gs4, 0.5),
      note(:as4, 0.5),
      note(:b4, 0.5),
      note(:cs5, 0.5),
      note(:d5, 0.5, sustain: 1),
      rest(0.5),
      note(:cs5, 0.25),
      note(:b4, 0.25),
      note(:a4, 0.25),
      note(:gs4, 0.25)
    ])
  end

  defp bar(:alto, 22) do
    seq(cs5: 0.5, b4: 0.5, a4: 0.5, b4: 0.5, a4: 0.5, gs4: 0.5, fs4: 1.5, fs4: 1, r: 0.5)
  end

  defp bar(:alto, 23), do: seq(r: 6)
  defp bar(:alto, 24), do: seq(r: 6)
  defp bar(:alto, 25), do: seq(r: 6)
  defp bar(:alto, 26), do: seq(r: 3, r: 1, r: 0.5, cs5: 0.75, b4: 0.25, a4: 0.25, gs4: 0.25)

  defp bar(:alto, 27) do
    seq([
      note(:a4, 3, sustain: 3.75),
      rest(0.75),
      note(:a4, 0.125),
      note(:b4, 0.125),
      note(:c5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:b4, 0.25),
      note(:a4, 0.5)
    ])
  end

  defp bar(:alto, 28) do
    seq([
      note(:g4, 3, sustain: 3.5),
      rest(0.5),
      note(:fs4, 0.5),
      note(:gs4, 0.5),
      note(:as4, 0.5),
      note(:b4, 0.5),
      note(:cs5, 0.5)
    ])
  end

  defp bar(:alto, 29) do
    seq([
      note(:d5, 3, sustain: 3.75),
      rest(0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5),
      note(:d5, 0.75),
      note(:cs5, 0.25),
      note(:b4, 0.5)
    ])
  end

  defp bar(:alto, 30) do
    seq(
      a4: 0.5,
      fs4: 0.5,
      gs4: 0.5,
      a4: 1.5,
      a4: 0.5,
      bs4: 0.5,
      cs5: 0.5,
      ds5: 0.5,
      fs4: 0.5,
      a4: 0.5
    )
  end

  defp bar(:alto, 31) do
    seq([
      note(:gs4, 0.75),
      note(:cs5, 0.25),
      note(:a4, 0.5),
      note(:fs4, 1.5, sustain: 2),
      rest(0.5),
      note(:es4, 0.5),
      note(:fs4, 0.5),
      note(:a4, 0.5),
      note(:d5, 0.25),
      note(:bs4, 0.25),
      note(:cs5, 0.5)
    ])
  end

  defp bar(:alto, 32) do
    seq([
      note(:fs4, 0.75),
      note(:a4, 0.25),
      note(:gs4, 0.5),
      note(:gs4, 0.5),
      note(:fs4, 0.25),
      note(:e4, 0.25),
      note(:ds4, 0.25),
      note(:cs4, 0.25),
      note(:cs4, 1.5, sustain: 2.5),
      rest(1),
      rest(0.5)
    ])
  end

  defp bar(:alto, 33), do: seq(r: 3, r: 1, r: 0.5, r: 0.5, r: 0.5, fs4: 0.5)

  defp bar(:alto, 34) do
    seq(
      d5: 0.75,
      cs5: 0.125,
      d5: 0.125,
      e5: 0.5,
      e5: 0.75,
      d5: 0.25,
      cs5: 0.5,
      b4: 1,
      e4: 0.5,
      ds4: 1,
      b4: 0.5
    )
  end

  defp bar(:alto, 35) do
    seq([
      note(:c5, 1),
      note(:b4, 0.5),
      note(:b4, 1),
      note(:as4, 0.5),
      note(:as4, 1),
      note(:b4, 0.5),
      note(:cs5, 1.5, sustain: 2.25)
    ])
  end

  defp bar(:alto, 36) do
    seq(
      r: 0.75,
      as4: 0.25,
      b4: 0.5,
      cs5: 0.25,
      d5: 0.25,
      e5: 0.5,
      cs5: 0.5,
      as4: 1,
      gs4: 0.5,
      fs4: 1,
      e4: 0.5
    )
  end

  defp bar(:alto, 37) do
    seq([
      note(:ds4, 0.5),
      note(:fs4, 0.25),
      note(:a4, 0.25),
      note(:c5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:b4, 0.25),
      note(:a4, 0.5),
      note(:g4, 1.5, sustain: 2.5),
      rest(1),
      note(:b4, 0.5)
    ])
  end

  defp bar(:alto, 38) do
    seq([
      note(:e4, 0.75),
      note(:fs4, 0.25),
      note(:g4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:fs4, 0.25),
      note(:e4, 0.5),
      note(:d4, 1),
      note(:cs4, 0.5),
      note(:d4, 0.75),
      note(:fs4, 0.25),
      note(:e4, 0.5)
    ])
  end

  defp bar(:alto, 39) do
    seq([
      note(:fs4, 3, sustain: 3.75),
      rest(0.75),
      note(:e4, 0.25),
      note(:ds4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:e4, 0.25),
      note(:fs4, 0.5)
    ])
  end

  defp bar(:alto, 40) do
    seq([
      note(:g4, 0.75),
      note(:fs4, 0.125),
      note(:g4, 0.125),
      note(:a4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:g4, 0.25),
      note(:fs4, 0.5),
      note(:e4, 1.5, sustain: 2.5),
      rest(1),
      note(:g4, 0.5)
    ])
  end

  defp bar(:alto, 41) do
    seq([
      note(:c5, 1),
      note(:b4, 0.5),
      note(:b4, 1),
      note(:as4, 0.5),
      note(:as4, 0.75),
      note(:e4, 0.125),
      note(:fs4, 0.125),
      note(:g4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:e4, 0.25),
      note(:fs4, 0.5)
    ])
  end

  defp bar(:alto, 42) do
    seq([
      note(:d5, 0.75),
      note(:cs5, 0.25),
      note(:e5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:d5, 0.25),
      note(:cs5, 0.5),
      note(:as4, 1),
      note(:gs4, 0.5),
      note(:fs4, 1),
      rest(0.5)
    ])
  end

  defp bar(:alto, 43) do
    seq([
      rest(1),
      rest(0.5),
      rest(0.5),
      rest(0.5),
      note(:cs5, 0.5),
      note(:e4, 0.75),
      note(:fs4, 0.25),
      note(:g4, 0.5, sustain: 1.25),
      rest(0.75),
      note(:fs4, 0.25),
      note(:e4, 0.5)
    ])
  end

  defp bar(:alto, 44) do
    seq([
      note(:ds4, 1),
      note(:b3, 0.5),
      note(:a4, 0.75),
      note(:fs4, 0.25),
      note(:ds4, 0.25),
      note(:e4, 0.25),
      note(:a4, 0.75),
      note(:b4, 0.25),
      note(:c5, 0.5, sustain: 1.25),
      rest(0.75),
      note(:b4, 0.25),
      note(:a4, 0.5)
    ])
  end

  defp bar(:alto, 45) do
    seq([
      note(:g4, 0.5),
      note(:a4, 0.5),
      note(:b4, 0.5, sustain: 1),
      rest(0.5),
      note(:cs5, 0.5),
      note(:ds5, 0.5),
      note(:e5, 0.75),
      note(:d5, 0.125),
      note(:c5, 0.125),
      note(:b4, 0.25),
      note(:a4, 0.25),
      note(:g4, 0.5),
      note(:fs4, 0.25),
      note(:e4, 0.25),
      note(:d4, 0.25),
      note(:cs4, 0.25)
    ])
  end

  defp bar(:alto, 46) do
    seq(
      fs4: 0.75,
      gs4: 0.125,
      as4: 0.125,
      b4: 0.125,
      cs5: 0.125,
      d5: 0.125,
      cs5: 0.125,
      e5: 0.5,
      d5: 0.5,
      cs5: 0.5,
      b4: 1.5,
      b4: 1,
      r: 0.5
    )
  end

  defp bar(:organo_a_canne, 0), do: together([seq(r: 0.5), seq(b2: 0.5)])

  defp bar(:organo_a_canne, 1) do
    together([
      seq([note(:b4, 3, sustain: 4.5), rest(1.5), note(:ds5, 1.5)]),
      seq(fs4: 3, g4: 1.5, a4: 1.5),
      seq([note(:d4, 3, sustain: 4.5), rest(1.5), note(:fs4, 1.5)]),
      seq(
        b3: 0.5,
        b3: 0.5,
        b3: 0.5,
        a3: 0.5,
        a3: 0.5,
        a3: 0.5,
        g3: 0.5,
        g3: 0.5,
        g3: 0.5,
        fs3: 0.5,
        fs3: 0.5,
        fs3: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 2) do
    together([
      seq(e5: 1.5, ds5: 1.5, e5: 3),
      seq(b4: 3, b4: 3),
      seq(b3: 1.5, a3: 1.5, g3: 1.5, g4: 1.5),
      seq(
        e3: 0.5,
        e3: 0.5,
        e3: 0.5,
        fs3: 0.5,
        fs3: 0.5,
        fs3: 0.5,
        g3: 0.5,
        e3: 0.5,
        g3: 0.5,
        b3: 0.5,
        g3: 0.5,
        b3: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 3) do
    together([
      seq([note(:g5, 3, sustain: 4.5), rest(1.5), note(:cs5, 1.5)]),
      seq([note(:e5, 3, sustain: 6), rest(3)]),
      seq(c5: 1.5, b4: 1.5, as4: 1.5, cs5: 1.5),
      seq(
        e4: 0.5,
        e4: 0.5,
        e4: 0.5,
        d4: 0.5,
        d4: 0.5,
        d4: 0.5,
        cs4: 0.5,
        cs4: 0.5,
        cs4: 0.5,
        as3: 0.5,
        as3: 0.5,
        as3: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 4) do
    together([
      seq([note(:d5, 1.5), note(:e5, 1.5), note(:fs5, 1.5, sustain: 2.5), rest(1), rest(0.5)]),
      seq([note(:d5, 1.5), note(:b4, 1.5), note(:as4, 1.5, sustain: 2.5), rest(1), rest(0.5)]),
      seq(r: 5.5, r: 0.5),
      seq(fs4: 1.5, g4: 1.5, cs4: 1.5, cs5: 1, r: 0.5),
      seq(
        b3: 0.5,
        b3: 0.5,
        b3: 0.5,
        g3: 0.5,
        g3: 0.5,
        g3: 0.5,
        fs3: 0.5,
        cs3: 0.5,
        e3: 0.5,
        e3: 0.5,
        as2: 0.5,
        cs3: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 5) do
    together([
      seq([
        note(:as4, 0.5),
        note(:b4, 0.5),
        note(:cs5, 0.5),
        note(:cs5, 0.5),
        note(:d5, 0.5),
        note(:e5, 0.5),
        note(:e5, 1.5, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq(fs4: 0.5, gs4: 0.5, as4: 0.5, as4: 0.5, b4: 0.5, cs5: 0.5, cs5: 1.5, cs5: 1, r: 0.5),
      seq(cs4: 0.5, d4: 0.5, e4: 0.5, fs3: 0.5, fs3: 0.5, fs3: 0.5, as4: 1.5, as4: 1, r: 0.5),
      seq(
        fs2: 1,
        r: 0.5,
        r: 1,
        r: 0.5,
        fs2: 0.5,
        fs2: 0.5,
        fs2: 0.5,
        fs2: 0.5,
        fs2: 0.5,
        fs2: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 6) do
    together([
      seq([
        note(:fs4, 0.5),
        note(:g4, 0.5),
        note(:a4, 0.5),
        note(:fs4, 0.5),
        note(:g4, 0.5),
        note(:a4, 0.5),
        note(:a4, 1.5, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq(ds4: 0.5, e4: 0.5, fs4: 0.5, ds4: 0.5, e4: 0.5, fs4: 0.5, r: 1, r: 2),
      seq([
        note(:a3, 0.5),
        note(:g3, 0.5),
        note(:fs3, 0.5),
        note(:b3, 0.5),
        note(:b3, 0.5),
        note(:b3, 0.5),
        note(:ds4, 1.5, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq(b2: 1, r: 1, r: 1, b2: 0.5, b2: 0.5, b2: 0.5, b2: 0.5, b2: 0.5, b2: 0.5)
    ])
  end

  defp bar(:organo_a_canne, 7) do
    together([
      seq(g4: 1.5, b4: 1.5, e5: 1.5, g5: 0.5, fs5: 1),
      seq(e4: 1.5, g4: 1.5, c5: 1.5, e5: 0.5, cs5: 1),
      seq(b3: 1.5, e4: 1.5, g4: 1.5, cs5: 0.5, as4: 1),
      seq(
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e2: 0.5,
        e3: 0.5
      )
    ])
  end

  defp bar(:organo_a_canne, 8) do
    together([
      seq([
        note(:fs5, 0.5),
        note(:e5, 0.5),
        note(:d5, 0.5),
        note(:e5, 0.5),
        note(:d5, 0.5),
        note(:cs5, 0.5),
        note(:b4, 0.5),
        note(:cs5, 0.5),
        note(:d5, 0.5),
        note(:cs5, 0.5),
        note(:d5, 0.5),
        note(:e5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:d5, 0.5),
        note(:as4, 0.5),
        note(:b4, 0.5),
        note(:b4, 0.5),
        note(:b4, 0.5),
        note(:as4, 0.5),
        note(:fs4, 0.5),
        note(:as4, 0.5),
        note(:b4, 0.5),
        note(:as4, 0.5),
        note(:b4, 0.5),
        note(:cs5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b4, 0.5),
        note(:as4, 0.5),
        note(:fs4, 0.5),
        note(:cs4, 0.5),
        note(:d4, 0.5),
        note(:e4, 0.5),
        note(:d4, 0.5),
        note(:e4, 0.5),
        note(:fs4, 0.5),
        note(:e4, 0.5),
        note(:fs4, 0.5),
        note(:as4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:d3, 0.5),
        note(:cs3, 0.5),
        note(:b2, 0.5),
        note(:fs3, 0.5),
        note(:fs3, 0.5),
        note(:fs2, 0.5),
        note(:b2, 1.5, sustain: 2.5),
        rest(1),
        note(:b2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 9) do
    together([
      seq([note(:d5, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:ds5, 1.5, vel: 0.3)]),
      seq([note(:b4, 3, vel: 0.3), note(:b4, 1.5, vel: 0.3), note(:a4, 1.5, vel: 0.3)]),
      seq([note(:fs4, 3, vel: 0.3), note(:g4, 1.5, vel: 0.3), note(:a4, 1.5, vel: 0.3)]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 10) do
    together([
      seq([
        note(:e5, 1.5, vel: 0.3),
        note(:c5, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3)
      ]),
      seq([note(:b4, 1.5, vel: 0.3), note(:a4, 1.5, vel: 0.3), note(:b4, 3, vel: 0.3)]),
      seq([note(:g4, 1.5, vel: 0.3), note(:fs4, 1.5, vel: 0.3), note(:g4, 3, vel: 0.3)]),
      seq([
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 11) do
    together([
      seq([note(:g5, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:cs5, 1.5, vel: 0.3)]),
      seq([note(:e5, 3, vel: 0.3), note(:e5, 1.5, vel: 0.3), note(:e5, 1.5, vel: 0.3)]),
      seq([note(:e4, 3, vel: 0.3), note(:e3, 1.5, vel: 0.3), note(:as3, 1.5, vel: 0.3)]),
      seq([
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 12) do
    together([
      seq([
        note(:d5, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3),
        note(:fs5, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:d5, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:fs3, 1, vel: 0.3),
        rest(2)
      ])
    ])
  end

  defp bar(:organo_a_canne, 13) do
    together([
      seq([
        note(:c5, 0.75, vel: 0.3),
        note(:b4, 0.25, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:ds5, 0.75, vel: 0.3),
        note(:e5, 0.25, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:e5, 1, vel: 0.3),
        note(:e5, 1, vel: 0.3),
        note(:b4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3)
      ]),
      seq([note(:b2, 1, vel: 0.3), rest(1), rest(1), note(:e3, 1, vel: 0.3), rest(2)])
    ])
  end

  defp bar(:organo_a_canne, 14) do
    together([
      seq([
        note(:d5, 0.75, vel: 0.3),
        note(:cs5, 0.25, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:es5, 0.75, vel: 0.3),
        note(:fs5, 0.25, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:fs5, 1, vel: 0.3),
        note(:fs5, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:es4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:es5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3)
      ]),
      seq([note(:cs3, 1, vel: 0.3), rest(1), rest(1), note(:fs3, 1, vel: 0.3), rest(2)])
    ])
  end

  defp bar(:organo_a_canne, 15) do
    together([
      seq([note(:cs5, 3, vel: 0.3), note(:d5, 1.5, vel: 0.3), note(:e5, 1.5, vel: 0.3)]),
      seq([note(:fs5, 3, vel: 0.3), note(:fs5, 1.5, vel: 0.3), note(:as4, 1.5, vel: 0.3)]),
      seq([
        note(:a4, 3, vel: 0.3, sustain: 3.5),
        rest(0.5),
        note(:gs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 16) do
    together([
      seq([note(:d5, 1.5, vel: 0.3), note(:cs5, 1.5, vel: 0.3), note(:b4, 3, vel: 0.3)]),
      seq([
        note(:b4, 1.5, vel: 0.3),
        note(:e5, 1, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3)
      ]),
      seq([note(:fs4, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:d4, 1.5, vel: 0.3)]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 17) do
    together([
      seq([note(:b4, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:b4, 1.5, vel: 0.3)]),
      seq([note(:d5, 3, vel: 0.3), note(:d5, 1.5, vel: 0.3), note(:gs4, 1.5, vel: 0.3)]),
      seq([
        rest(1.5),
        note(:fs4, 1.5, vel: 0.3),
        note(:gs4, 1.5, vel: 0.3),
        note(:gs4, 1.5, vel: 0.3)
      ]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 18) do
    together([
      seq([
        note(:a4, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:cs5, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:a4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:gs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:cs4, 1.5, vel: 0.3),
        note(:d4, 1.5, vel: 0.3),
        note(:gs3, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:gs2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:es2, 0.5, vel: 0.3),
        note(:gs2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 19) do
    together([
      seq([
        note(:es5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:a5, 0.5, vel: 0.3),
        note(:b5, 0.5, vel: 0.3),
        note(:es5, 1.5, vel: 0.3),
        note(:es5, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:cs5, 0.5, vel: 0.3),
        note(:ds5, 0.5, vel: 0.3),
        note(:es5, 0.5, vel: 0.3),
        note(:es5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:gs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:cs2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 20) do
    together([
      seq([
        note(:cs5, 0.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:as4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 21) do
    together([
      seq([
        note(:d4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:cs5, 1, vel: 0.3)
      ]),
      seq([
        note(:b3, 1.5, vel: 0.3),
        note(:d4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:gs4, 1, vel: 0.3)
      ]),
      seq([
        note(:fs3, 1.5, vel: 0.3),
        note(:b3, 1.5, vel: 0.3),
        note(:d4, 1.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:es4, 1, vel: 0.3)
      ]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 22) do
    together([
      seq([
        note(:cs5, 1, vel: 0.3),
        rest(1),
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:a4, 1.5, vel: 0.3),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:a4, 1, vel: 0.3),
        rest(1),
        note(:fs4, 0.5, vel: 0.3),
        note(:es4, 0.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs4, 1, vel: 0.3),
        rest(1),
        note(:cs4, 2, vel: 0.3),
        rest(0.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:a2, 0.5, vel: 0.3),
        note(:gs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:a2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:a2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 23) do
    together([
      seq([
        note(:cs5, 3, vel: 0.3, sustain: 4),
        rest(1),
        note(:b4, 0.5, vel: 0.3),
        note(:b4, 1, vel: 0.3),
        note(:as4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:a4, 3, vel: 0.3, sustain: 4),
        rest(1),
        note(:b4, 0.5, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 3, vel: 0.3, sustain: 4),
        rest(1),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 1.5, vel: 0.3)
      ]),
      seq([
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 24) do
    together([
      seq([
        note(:b4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        note(:fs4, 0.5, vel: 0.3),
        note(:b4, 1, vel: 0.3),
        note(:d5, 0.5, vel: 0.3)
      ]),
      seq([note(:d5, 1.5, vel: 0.3), note(:as4, 1.5, vel: 0.3), note(:b4, 3, vel: 0.3)]),
      seq([note(:fs4, 1.5, vel: 0.3), note(:e4, 1.5, vel: 0.3), note(:d4, 3, vel: 0.3)]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 25) do
    together([
      seq([
        note(:g5, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3),
        note(:es5, 1.5, vel: 0.3),
        note(:gs5, 1.5, vel: 0.3, sustain: 2)
      ]),
      seq([note(:b4, 6, vel: 0.3)]),
      seq([note(:d4, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:gs3, 1.5, vel: 0.3)]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 26) do
    together([
      seq([
        rest(0.5),
        note(:es5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:gs5, 0.125, vel: 0.3),
        note(:a5, 0.125, vel: 0.3),
        note(:b5, 0.25, vel: 0.3),
        note(:a5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:es5, 0.5, vel: 0.3),
        note(:cs5, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:cs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:a4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:a3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:a2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 27) do
    together([
      seq([
        note(:fs5, 3, vel: 0.3, sustain: 3.75),
        rest(0.75),
        note(:fs5, 0.125, vel: 0.3),
        note(:g5, 0.125, vel: 0.3),
        note(:a5, 0.5, vel: 0.3),
        note(:a5, 0.75, vel: 0.3),
        note(:g5, 0.25, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:c5, 0.5, vel: 0.3),
        note(:c5, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:c5, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:ds5, 0.5, vel: 0.3),
        note(:ds5, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:fs2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 28) do
    together([
      seq([
        note(:e5, 3, vel: 0.3, sustain: 3.5),
        rest(0.5),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3, sustain: 1.5),
        note(:cs5, 0.25, vel: 0.3),
        note(:d5, 0.25, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:ds4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:ds4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:e3, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 29) do
    together([
      seq([
        note(:b4, 3, vel: 0.3, sustain: 3.75),
        rest(0.75),
        note(:a4, 0.25, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:b4, 0.75, vel: 0.3),
        note(:a4, 0.25, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:ds4, 0.5, vel: 0.3),
        note(:es4, 0.5, vel: 0.3),
        note(:es4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:gs3, 1, vel: 0.3),
        rest(0.5),
        note(:gs4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:b2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 30) do
    together([
      seq([
        note(:fs4, 1.5, vel: 0.3),
        note(:a4, 1.5, vel: 0.3),
        note(:d5, 1, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:gs5, 0.5, vel: 0.3),
        rest(0.5),
        note(:ds5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:cs4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:a4, 1.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        rest(0.5),
        note(:gs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:a3, 1.5, vel: 0.3),
        note(:cs4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:bs3, 0.5, vel: 0.3),
        rest(0.5),
        rest(0.5)
      ]),
      seq([
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:ds3, 0.5, vel: 0.3),
        note(:bs2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 31) do
    together([
      seq([
        note(:cs5, 1, vel: 0.3),
        rest(0.5),
        note(:cs5, 1.5, vel: 0.3),
        note(:d5, 1.5, vel: 0.3),
        note(:cs5, 1.5, vel: 0.3)
      ]),
      seq([note(:gs4, 1, vel: 0.3), rest(0.5), note(:a4, 3, vel: 0.3), note(:a4, 1.5, vel: 0.3)]),
      seq([rest(1), rest(0.5), note(:fs4, 3, vel: 0.3, sustain: 4.5), rest(1.5)]),
      seq([
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 32) do
    together([
      seq([
        note(:bs4, 1, vel: 0.3),
        note(:bs4, 0.5, vel: 0.3),
        note(:cs5, 1, vel: 0.3),
        note(:bs4, 0.5, vel: 0.3),
        rest(1.5),
        note(:cs5, 1.5, vel: 0.3)
      ]),
      seq([
        note(:a4, 1, vel: 0.3),
        note(:ds4, 0.5, vel: 0.3),
        note(:gs4, 1.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3, sustain: 1),
        rest(0.5),
        note(:a4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3)
      ]),
      seq([note(:fs4, 1, vel: 0.3), rest(0.5), rest(1), rest(0.5), note(:es4, 3, vel: 0.3)]),
      seq([
        note(:ds3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:gs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3),
        note(:es3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 33) do
    together([
      seq([
        note(:cs5, 1.5, vel: 0.3),
        note(:es5, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 1.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:a4, 1, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 1.5, vel: 0.3)
      ]),
      seq([
        note(:a4, 1.5, vel: 0.3),
        note(:cs5, 1, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:fs4, 3, vel: 0.3)
      ]),
      seq([
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 34) do
    together([
      seq([
        note(:d5, 1.5, vel: 0.3),
        note(:cs5, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3)
      ]),
      seq([
        note(:b4, 1.5, vel: 0.3),
        note(:as4, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:b4, 1, vel: 0.3),
        note(:ds5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 1, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3)
      ]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 35) do
    together([
      seq([note(:g5, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:cs5, 1.5, vel: 0.3)]),
      seq([note(:e5, 3, vel: 0.3), note(:e5, 3, vel: 0.3)]),
      seq([note(:e4, 3, vel: 0.3), note(:e3, 1.5, vel: 0.3), note(:as3, 1.5, vel: 0.3)]),
      seq([
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 36) do
    together([
      seq([
        note(:d5, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        note(:as4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:d5, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:g2, 0.5, vel: 0.3),
        note(:fs3, 1, vel: 0.3),
        rest(2)
      ])
    ])
  end

  defp bar(:organo_a_canne, 37) do
    together([
      seq([
        note(:c5, 0.75, vel: 0.3),
        note(:b4, 0.25, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:ds5, 0.75, vel: 0.3),
        note(:e5, 0.25, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:fs5, 0.5, vel: 0.3),
        note(:e5, 1, vel: 0.3, sustain: 2),
        rest(1),
        note(:g4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3)
      ]),
      seq([note(:b2, 1, vel: 0.3), rest(1), rest(1), note(:e3, 1, vel: 0.3), rest(2)])
    ])
  end

  defp bar(:organo_a_canne, 38) do
    together([
      seq([
        note(:g4, 0.75, vel: 0.3),
        note(:fs4, 0.25, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:as4, 0.75, vel: 0.3),
        note(:b4, 0.25, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:b4, 1, vel: 0.3, sustain: 2),
        rest(1),
        note(:cs5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:as3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3)
      ]),
      seq([note(:fs3, 1, vel: 0.3), rest(1), rest(1), note(:b2, 1, vel: 0.3), rest(2)])
    ])
  end

  defp bar(:organo_a_canne, 39) do
    together([
      seq([
        note(:d5, 3, vel: 0.3, sustain: 3.5),
        rest(0.5),
        note(:cs5, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3)
      ]),
      seq([note(:b4, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:ds5, 1.5, vel: 0.3)]),
      seq([
        note(:b3, 3, vel: 0.3, sustain: 4.5),
        rest(1.5),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:a3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 40) do
    together([
      seq([note(:b4, 3, vel: 0.3), note(:b4, 3, vel: 0.3)]),
      seq([
        note(:e5, 1.5, vel: 0.3),
        note(:a5, 1, vel: 0.3),
        note(:ds5, 0.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3)
      ]),
      seq([note(:g4, 1.5, vel: 0.3), note(:fs4, 1.5, vel: 0.3), note(:e4, 3, vel: 0.3)]),
      seq([
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 41) do
    together([
      seq([note(:g4, 3, vel: 0.3, sustain: 4.5), rest(1.5), note(:cs5, 1.5, vel: 0.3)]),
      seq([
        note(:c5, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3, sustain: 3),
        rest(1.5),
        note(:e5, 0.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3)
      ]),
      seq([
        note(:e4, 3, vel: 0.3, sustain: 4.5),
        rest(1.5),
        note(:e4, 1, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3)
      ]),
      seq([
        note(:e4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:cs4, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3),
        note(:as3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 42) do
    together([
      seq([
        note(:fs5, 1.5, vel: 0.3),
        note(:e5, 1.5, vel: 0.3),
        note(:fs5, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([note(:b4, 3, vel: 0.3), note(:cs5, 1.5, vel: 0.3, sustain: 2.5), rest(1), rest(0.5)]),
      seq([note(:b3, 3, vel: 0.3), note(:fs4, 1.5, vel: 0.3, sustain: 2.5), rest(1), rest(0.5)]),
      seq([
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:g3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3),
        note(:as2, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 43) do
    together([
      seq([
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:d5, 0.5, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:as4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:gs4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:cs5, 0.5, vel: 0.3),
        note(:cs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:cs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 44) do
    together([
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:a4, 0.5, vel: 0.3),
        note(:a4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:ds4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:ds4, 0.5, vel: 0.3),
        note(:e4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:fs3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 0.5, vel: 0.3),
        note(:b3, 1.5, vel: 0.3, sustain: 2.5),
        rest(1),
        rest(0.5)
      ]),
      seq([
        note(:b2, 1, vel: 0.3),
        rest(1),
        rest(1),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 45) do
    together([
      seq([
        note(:g4, 1.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note([:c5, :e5], 1.5, vel: 0.3),
        note(:e5, 0.5, vel: 0.3),
        note(:cs5, 1, vel: 0.3)
      ]),
      seq([
        note(:e4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3),
        rest(1.5),
        note(:cs5, 0.5, vel: 0.3),
        note(:as4, 1, vel: 0.3)
      ]),
      seq([
        note(:b3, 1.5, vel: 0.3),
        note(:e4, 1.5, vel: 0.3),
        note(:g4, 1.5, vel: 0.3),
        note(:g4, 0.5, vel: 0.3),
        note(:fs4, 1, vel: 0.3)
      ]),
      seq([
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e2, 0.5, vel: 0.3),
        note(:e3, 0.5, vel: 0.3)
      ])
    ])
  end

  defp bar(:organo_a_canne, 46) do
    together([
      seq([
        note(:b4, 0.5, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 0.5, vel: 0.3),
        note(:b4, 1, vel: 0.3),
        note(:as4, 0.5, vel: 0.3),
        note(:b4, 1.5, vel: 0.3),
        note(:fs4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        note(:fs4, 0.5, vel: 0.3),
        note(:fs4, 0.5, vel: 0.3),
        note(:d4, 0.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:fs4, 1.5, vel: 0.3),
        note(:d4, 1, vel: 0.3),
        rest(0.5)
      ]),
      seq([
        rest(0.5),
        rest(0.5),
        rest(0.5),
        note(:cs4, 1.5, vel: 0.3),
        note(:d4, 1.5, vel: 0.3),
        rest(0.5),
        rest(1)
      ]),
      seq([
        note(:d3, 0.5, vel: 0.3),
        note(:cs3, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:d2, 0.5, vel: 0.3),
        note(:fs2, 0.5, vel: 0.3),
        note(:b2, 0.5, vel: 0.3),
        note(:d3, 0.5, vel: 0.3),
        note(:fs3, 0.5, vel: 0.3)
      ])
    ])
  end
end
