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

    test "> accents a word, inside brackets too, and a fraction is a length" do
      assert Pattern.parse(">h [f >f] >g5/b4 c4:1/3 _:3/2") == [
               %{tokens: ["h"], steps: 1, accent: true},
               %{tokens: ["f"], steps: 0.5},
               %{tokens: ["f"], steps: 0.5, accent: true},
               %{tokens: ["g5", "b4"], steps: 1, accent: true},
               %{tokens: ["c4"], steps: 1 / 3},
               %{tokens: [], steps: 1.5}
             ]

      assert ~MX">x."s == [
               %{tokens: [">"], steps: 1, char: true},
               %{tokens: ["x"], steps: 1, char: true},
               %{tokens: [], steps: 1, char: true}
             ]
    end

    test "refuse an accent on a silence, a hold or a glide, and a fraction that is not above 0" do
      for word <- [">_", ">-", ">~g4"] do
        assert_raise ArgumentError, ~r/^#{word} accents/, fn -> Pattern.parse("f " <> word) end
      end

      for word <- ["c4:1/0", "c4:0/2", "c4:-1/2", "c4:1/x"] do
        assert_raise ArgumentError, ~r/^#{word} takes its length/, fn -> Pattern.parse(word) end
      end

      for text <- ["f >_", "c4:1/0"] do
        error =
          assert_raise CompileError, fn ->
            Code.eval_string("import Mx\n\n~MX\"#{text}\"", [], file: "song.exs")
          end

        assert Exception.message(error) =~ "song.exs:3: ~MX: "
      end
    end

    test "^ makes a grace note, which takes no step" do
      assert Pattern.parse("b5 ^d6 c6") == [
               %{tokens: ["b5"], steps: 1},
               %{tokens: ["d6"], steps: 0, grace: true},
               %{tokens: ["c6"], steps: 1}
             ]

      assert [%{tokens: ["^"]}, %{tokens: ["x"]}] = ~MX"^x"s
    end

    test "refuse a grace note before a silence, a hold or a glide, with a length, or at the end" do
      for text <- ["c4 ^d4 _", "c4 ^d4 -", "c4 ^d4 ~e4", "c4 ^d4", "c4 ^d4:2 e4"] do
        assert_raise ArgumentError, ~r/\^d4/, fn -> Pattern.parse(text) end

        error =
          assert_raise CompileError, fn ->
            Code.eval_string("import Mx\n\n~MX\"#{text}\"", [], file: "song.exs")
          end

        assert Exception.message(error) =~ "song.exs:3: ~MX: "
      end
    end

    test "~MX with s reads a character to a step, and refuses another modifier" do
      assert ~MX"9. x|c"s == [
               %{tokens: ["9"], steps: 1, char: true},
               %{tokens: [], steps: 1, char: true},
               %{tokens: ["x"], steps: 1, char: true},
               %{tokens: ["c"], steps: 1, char: true}
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
               items: [
                 %Sample{ref: {:sonic_pi, :bd_haus}, beats: 0.5, opts: [amp: 1.0]},
                 %Sample{opts: []}
               ]
             } =
               steps("9x", 0.5, sample: {:sonic_pi, :bd_haus})
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

    test "plays an accented word with accent:, a number added to its vel up to 1 or options in place of its own" do
      vels = fn music -> for %Note{opts: opts} <- music.items, do: opts[:vel] end
      word = ~MX"f >f"

      assert word |> steps(0.25, strokes: [f: [vel: 0.5]], accent: 0.25) |> vels.() == [
               0.5,
               0.75
             ]

      assert word |> steps(0.25, strokes: [f: [vel: 0.5]], accent: [vel: 0.9]) |> vels.() ==
               [
                 0.5,
                 0.9
               ]

      assert word |> steps(0.25, strokes: [f: [vel: 0.9]], accent: 0.25) |> vels.() == [
               0.9,
               1
             ]

      assert %Seq{items: [%Note{pitch: 67, opts: [vel: 0.6]}, %Note{pitch: 67, opts: [vel: 0.8]}]} =
               steps(~MX"g4 >g4", 0.25, vel: 0.6, accent: 0.2)

      assert %Seq{items: [%Note{beats: 0.25}, %Note{beats: 0.25}]} =
               steps(~MX"f >f", 0.25, strokes: [f: [vel: 0.5]], accent: 0.25)
    end

    test "refuses an accented word without accent:, and a number for a sound with no vel" do
      assert_raise ArgumentError, "steps plays the accented word >f and has no accent:", fn ->
        steps(~MX"f >f", 0.25, strokes: [f: [vel: 0.5]])
      end

      assert_raise ArgumentError, ~r/>f/, fn ->
        steps(~MX"f >f", 0.25, strokes: [f: [muted: 1]], accent: 0.2)
      end
    end

    test "places notes whose lengths are fractions where the fractions add up" do
      music = steps(~MX"c4:1/3 d4:1/3 e4:1/3", 1)

      assert beats(music) == 1.0

      {starts, _} = Enum.map_reduce(music.items, 0, &{{&2, &1.pitch}, &2 + &1.beats})
      assert starts == [{0, 60}, {1 / 3, 62}, {2 / 3, 64}]
    end

    test "plays a grace note grace: beats before the word after it, 0.06 unless given" do
      assert %Together{
               items: [%Seq{items: words}, %Mx.Music.At{beats: 1.5, entries: [{beat, grace}]}]
             } =
               music = steps(~MX"b5 ^d6 c6 b5", 0.5)

      assert beats(music) == 1.5

      assert [
               %Note{pitch: 83, beats: 0.5},
               %Note{pitch: 84, beats: 0.5},
               %Note{pitch: 83, beats: 0.5}
             ] = words

      assert_in_delta beat, 0.44, 1.0e-9
      assert %Note{pitch: 86, beats: 0.06} = grace

      assert %Together{items: [_, %Mx.Music.At{entries: [{beat, %Note{beats: 0.1}}]}]} =
               steps(~MX"b5 ^d6 c6 b5", 0.5, grace: 0.1)

      assert_in_delta beat, 0.4, 1.0e-9

      assert %Together{
               items: [_, %Mx.Music.At{entries: [{d4, %Note{pitch: 62}}, {e4, %Note{pitch: 64}}]}]
             } =
               steps(~MX"c4 ^d4 ^e4 f4", 1)

      assert_in_delta d4, 0.88, 1.0e-9
      assert_in_delta e4, 0.94, 1.0e-9

      assert %Together{
               items: [
                 %Seq{items: [%Rest{}, %Note{opts: [vel: 0.9]}]},
                 %Mx.Music.At{
                   entries: [{flam, %Note{pitch: :own_note, beats: 0.05, opts: [vel: 0.3]}}]
                 }
               ]
             } =
               steps(~MX"_ ^s S", 0.25, strokes: [s: [vel: 0.3], S: [vel: 0.9]], grace: 0.05)

      assert_in_delta flam, 0.2, 1.0e-9
    end

    test "refuses a grace note that would start before the pattern" do
      assert_raise ArgumentError,
                   "steps plays the grace note ^d6 before the pattern starts; start the pattern with a silence",
                   fn -> steps(~MX"^d6 c6", 0.5) end
    end

    test "plays a word of words: as a note of its pitch, which glides, chords and takes marks" do
      assert %Seq{
               items: [%Note{pitch: 62, beats: 1}, %Note{pitch: 64}, %Note{pitch: 65}, %Rest{}]
             } =
               music = steps(~MX"S R g _", 1, words: [S: :d4, R: :e4, g: :f4])

      assert beats(music) == 4

      assert %Seq{
               items: [
                 %Note{
                   pitch: 62,
                   beats: 1.0,
                   opts: [changes: [{0.5, [note: 64, note_slide: 0.05]}]]
                 }
               ]
             } =
               steps(~MX"S:2 ~R:2", 0.25, words: [S: :d4, R: :e4], slide: 0.05)

      assert %Seq{items: [%Note{pitch: [62, 65]}]} = steps(~MX"S/g", 1, words: [S: :d4, g: :f4])

      assert %Seq{items: [%Note{pitch: 74}, %Note{pitch: 61}]} =
               steps(~MX"S' .n", 1, words: ["S'": :d5, ".n": :cs4])

      assert %Seq{items: [%Note{pitch: 69}]} = steps(~MX"f", 1, words: [f: :a4])
      assert %Seq{items: [%Note{pitch: [62, 66]}]} = steps(~MX"D", 1, words: [D: [:d4, 66]])
    end

    test "refuses a word that is in no list and no note, and words: with a pattern read a character to a step" do
      assert_raise ArgumentError, ~r/ q$/, fn -> steps(~MX"S q", 1, words: [S: :d4]) end

      assert_raise ArgumentError, ~r/words: goes with a pattern read a word to a step/, fn ->
        steps(~MX"S.S."s, 0.25, words: [S: :d4])
      end
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
