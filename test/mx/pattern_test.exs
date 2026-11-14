defmodule Mx.PatternTest do
  use ExUnit.Case, async: true

  import Mx

  alias Mx.Music.{Note, Rest, Sample, Seq, Together}
  alias Mx.Pattern

  describe "a pattern's words" do
    test "last a step each, or the steps after a colon, and _ is silence" do
      assert Pattern.parse("g4 _ a4:3 _:2 b4:1.5") == [
               %{tokens: ["g4"], steps: 1},
               %{tokens: [], steps: 1},
               %{tokens: ["a4"], steps: 3},
               %{tokens: [], steps: 2},
               %{tokens: ["b4"], steps: 1.5}
             ]
    end

    test "- holds the word before it, and a bar line is left out" do
      assert Pattern.parse("g4 - | -:2 _ -") == [
               %{tokens: ["g4"], steps: 4},
               %{tokens: [], steps: 2}
             ]
    end

    test "a slash joins words that sound together, and brackets share one step" do
      assert Pattern.parse("g5/b4 [f f:2 _]") == [
               %{tokens: ["g5", "b4"], steps: 1},
               %{tokens: ["f"], steps: 0.25},
               %{tokens: ["f"], steps: 0.5},
               %{tokens: [], steps: 0.25}
             ]
    end

    test "a word after ~ glides, and keeps its own length" do
      assert Pattern.parse("eb2:2 ~g2:1.5") == [
               %{tokens: ["eb2"], steps: 2},
               %{tokens: ["g2"], steps: 1.5, glide: true}
             ]
    end

    test "refuse a length that is no number and brackets that do not pair" do
      assert_raise ArgumentError, ~r/g4:x takes its length/, fn -> Pattern.parse("g4:x") end
      assert_raise ArgumentError, ~r/never closed/, fn -> Pattern.parse("[g4") end
      assert_raise ArgumentError, ~r/closes no/, fn -> Pattern.parse("g4 ]") end
      assert_raise ArgumentError, ~r/holds no words/, fn -> Pattern.parse("[ ]") end
    end

    test "~MX with s reads a character to a step, and refuses another modifier" do
      assert ~MX"9. x|c"s == [
               %{tokens: ["9"], steps: 1},
               %{tokens: [], steps: 1},
               %{tokens: ["x"], steps: 1},
               %{tokens: ["c"], steps: 1}
             ]

      assert steps(~MX"9.x"s, 0.25) == steps("9.x", 0.25)

      assert_raise CompileError, ~r/no modifier but s/, fn ->
        Code.eval_string("import Mx\n~MX\"x\"q")
      end
    end

    test "~MX reads them as the song compiles, and names the line of a mistake" do
      assert ~MX"g4:2 _" ++ ~MX"a4" == Pattern.parse("g4:2 _ a4")

      error =
        assert_raise CompileError, fn ->
          Code.eval_string("import Mx\n\n~MX\"g4:x\"", [], file: "song.exs")
        end

      assert Exception.message(error) =~ "song.exs:3: ~MX: g4:x takes its length"
    end
  end

  describe "steps" do
    test "plays a digit as a hit of that level, and a list as one bar after another" do
      assert %Seq{items: items} = steps(["9.", ".3"], 0.25, release: 0.1)

      assert items == [
               %Note{pitch: :own_note, beats: 0.25, opts: [vel: 1.0, release: 0.1]},
               %Rest{beats: 0.25},
               %Rest{beats: 0.25},
               %Note{pitch: :own_note, beats: 0.25, opts: [vel: 3 / 9, release: 0.1]}
             ]

      assert %Seq{items: [%Note{opts: [amp: 1.0]}]} = steps("9", 1, digit: :amp)
    end

    test "plays each hit as the sample of sample:, a digit its amp" do
      assert %Seq{
               items: [%Sample{ref: :bd_haus, beats: 0.5, opts: [amp: 1.0]}, %Sample{opts: []}]
             } =
               steps("9x", 0.5, sample: :bd_haus)
    end

    test "plays the characters of strokes: with their options, and a digit as a note of notes:" do
      assert %Seq{items: [%Note{opts: [vel: 0.5]}, %Note{opts: [vel: 0.75, sustain: 0.2]}]} =
               steps("co", 0.25, strokes: [o: [vel: 0.75, sustain: 0.2], c: [vel: 0.5]])

      assert %Seq{items: [%Note{pitch: :own_note, opts: [note: 69]}, %Rest{}]} =
               steps("2.", 0.25, notes: [:g4, :a4])

      assert_raise ArgumentError, ~r/no note 3 in notes:/, fn ->
        steps("3", 0.25, notes: [:g4, :a4])
      end
    end

    test "gives each sound the options each: returns for the step it starts on" do
      loud = fn step -> [vel: if(step == 2, do: 0.9, else: 0.5)] end

      assert %Seq{items: [%Note{opts: [vel: 0.5]}, %Rest{}, %Note{opts: [vel: 0.9]}]} =
               steps("x.x", 0.25, each: loud)
    end

    test "plays the words of a pattern as notes of their length, strokes and silence" do
      assert %Seq{items: items} =
               steps(~MX"g4:2 _ g5/b4 [T x]", 0.5, vel: 0.8, strokes: [T: [muted: 1]])

      assert [
               %Note{pitch: 67, beats: 1.0, opts: [vel: 0.8]},
               %Rest{beats: 0.5},
               %Note{pitch: [79, 71], beats: 0.5},
               %Note{pitch: :own_note, beats: 0.25, opts: [muted: 1, vel: 0.8]},
               %Note{pitch: :own_note, beats: 0.25, opts: [vel: 0.8]}
             ] = items

      assert %Seq{items: [%Together{items: [%Note{}, %Note{}]}]} = steps(~MX"x/x", 1)
    end

    test "a note glides to the words after ~, and lasts through them" do
      assert %Seq{
               items: [%Note{pitch: 39, beats: 1.0, opts: opts}, %Note{pitch: 38, beats: 0.25}]
             } =
               steps(~MX"eb2 ~g2 ~bb2:2 d2", 0.25, vel: 0.8, slide: 0.3)

      assert opts == [
               vel: 0.8,
               changes: [{0.25, [note: 43, note_slide: 0.3]}, {0.5, [note: 46, note_slide: 0.3]}]
             ]

      assert %Seq{items: [%Note{opts: [changes: [{1, [note: 43]}]]}]} = steps(~MX"eb2 ~g2", 1)

      for {pattern, message} <- [
            {~MX"~g2", ~r/~g2 glides from one note to one note/},
            {~MX"eb2 _ ~g2", ~r/~g2 glides from one note/},
            {~MX"eb2/g2 ~g2", ~r/~g2 glides from one note/},
            {~MX"x ~g2", ~r/glides from a note, not from the stroke x/}
          ] do
        assert_raise ArgumentError, message, fn -> steps(pattern, 1) end
      end
    end

    test "a function of two for each: takes the sound's length in steps as well" do
      short = fn step, steps -> [sustain: steps / 4, pan: step] end

      assert %Seq{
               items: [%Note{opts: [sustain: 0.75, pan: 0]}, %Note{opts: [sustain: 0.25, pan: 3]}]
             } =
               steps(~MX"g1:3 a1", 0.25, each: short)
    end

    test "refuses a character or a word that is no sound" do
      assert_raise ArgumentError, ~r/and \. for silence, not q/, fn -> steps("x.q", 0.25) end

      assert_raise ArgumentError, ~r/a stroke and a note together, as in x\/g4/, fn ->
        steps(~MX"x/g4", 1)
      end
    end
  end
end
