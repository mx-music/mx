defmodule Mx.MusicTest do
  use ExUnit.Case, async: true, group: :stderr

  import ExUnit.CaptureIO

  alias Mx.{Pass, Song}

  doctest Mx, import: true

  describe "loading a song written as music" do
    @tag :tmp_dir
    test "plays each part as a loop with one pass that ends the song", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(tempo: 72, music: part(:soprano, seq(c4: 1, d4: 1, e4: 2), synth: :oboe))"
        )

      assert song.tempo == 72
      assert [%{name: :soprano, synth: :oboe, passes: 1} = loop] = song.loops

      assert Pass.events(loop, 0) ==
               {:ok,
                %{
                  events: [{0, 60, [sustain: 1]}, {1, 62, [sustain: 1]}, {2, 64, [sustain: 2]}],
                  beats: 4,
                  notes: [{0, 60, 1}, {1, 62, 1}, {2, 64, 2}],
                  vels: [nil, nil, nil]
                }}
    end

    @tag :tmp_dir
    test "a note takes the synth's options, and its length is its sustain unless it gives one",
         ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:guitar, seq([note(:a4, 1.5, vel: 0.8), note(:b4, 1, sustain: 0.5)]), synth: :guitar))"
        )

      assert events(song, :guitar) == [
               {0, 69, [vel: 0.8, sustain: 1.5]},
               {1.5, 71, [sustain: 0.5]}
             ]
    end

    @tag :tmp_dir
    test "a part's default sustain stands in for each note's length", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:guitar, seq(a4: 1), synth: :guitar, defaults: [sustain: 3]))"
        )

      assert events(song, :guitar) == [{0, 69, [sustain: 3]}]
    end

    @tag :tmp_dir
    test "a chord strums, as play strums it", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:guitar, note(chord(:c4, :major), 2, strum: 0.05), synth: :guitar))"
        )

      assert [{+0.0, 60, _}, {+0.05, 64, _}, {0.1, 67, _}] = events(song, :guitar)
    end

    @tag :tmp_dir
    test "seq, together, repeat, transpose, at and steps place the notes", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:melody, seq(a4: 1.5, r: 1, c5: 1)),
          part(:harmony, together([seq(c4: 4), seq(e4: 1, f4: 1)])),
          part(:ostinato, repeat(seq(c4: 1), 3)),
          part(:descant, transpose(seq(c4: 1), 12)),
          part(:offbeats, at([{0.5, note(:c4, 0.5)}, {1.5, note(:e4, 0.5)}], 2)),
          part(:kick, steps("x..x", 0.25), synth: :kick)
        ]))
        """)

      assert played(events(song, :melody)) == [{0, 69}, {2.5, 72}]
      assert played(events(song, :harmony)) == [{0, 60}, {0, 64}, {1, 65}]
      assert played(events(song, :ostinato)) == [{0, 60}, {1, 60}, {2, 60}]
      assert played(events(song, :descant)) == [{0, 72}]
      assert played(events(song, :offbeats)) == [{0.5, 60}, {1.5, 64}]
      assert played(events(song, :kick)) == [{0, :own_note}, {0.75, :own_note}]
      assert {:ok, %{beats: 4}} = Pass.events(hd(song.loops), 0)
    end

    @tag :tmp_dir
    test "seq, together and at take a collection and a function that makes each item", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:rising, seq(1..3, fn n -> note(60 + n, 1) end)),
          part(:chord, together([:c4, :e4], fn name -> note(name, 2) end)),
          part(:strokes, at([{0, 0.4}, {1.5, 0.8}], 4, fn vel -> hit(vel: vel) end), synth: :kick),
          part(:pairs, seq([:c4, :e4], fn name -> {name, 1} end))
        ]))
        """)

      assert played(events(song, :rising)) == [{0, 61}, {1, 62}, {2, 63}]
      assert played(events(song, :chord)) == [{0, 60}, {0, 64}]

      assert [{0, :own_note, [vel: 0.4]}, {1.5, :own_note, [vel: 0.8]}] =
               events(song, :strokes)

      assert played(events(song, :pairs)) == [{0, 60}, {1, 64}]

      assert Mx.beats(Mx.seq(1..3, fn n -> Mx.note(60 + n, 1) end)) == 3
      assert Mx.beats(Mx.together([:c4, :e4], fn name -> Mx.note(name, 2) end)) == 2
      assert Mx.beats(Mx.at([{0, 0.4}, {1.5, 0.8}], 4, fn vel -> Mx.hit(vel: vel) end)) == 4
      assert Mx.beats(Mx.seq([:c4, :e4], fn name -> {name, 1} end)) == 2
    end

    @tag :tmp_dir
    test "form plays the music for each section in turn, a count playing it that many times",
         ctx do
      {:ok, song} =
        load(ctx, """
        song(music: part(:lead, form([a: 2, b: 1], fn name -> note(if(name == :a, do: :c4, else: :e4), 1) end)))
        """)

      assert played(events(song, :lead)) == [{0, 60}, {1, 60}, {2, 64}]
    end

    test "form calls a function of one argument with each name, and of two with its pass, time and coming" do
      names = fn sections ->
        Mx.form(sections, fn name -> send(self(), name) && Mx.rest(1) end)
        for _ <- sections, do: receive(do: (name -> name))
      end

      assert names.([:a, :b]) == [:a, :b]

      maps = fn opts ->
        Mx.form([a: 2, b: 1, a: 1], fn _name, map -> send(self(), map) && Mx.rest(1) end, opts)
        for _ <- 1..4, do: receive(do: (map -> map))
      end

      assert maps.([]) == [
               %{pass: 0, time: 0, coming: :a},
               %{pass: 1, time: 1, coming: :b},
               %{pass: 2, time: 0, coming: :a},
               %{pass: 3, time: 2, coming: nil}
             ]

      assert List.last(maps.(round: true)) == %{pass: 3, time: 2, coming: :a}
    end

    @tag :tmp_dir
    test "without and only leave parts out, and the music lasts as long as before", ctx do
      music = """
      together([
        part(:kick, at([{0, hit()}, {1, hit()}], 4), synth: :kick),
        part(:bass, note(:c2, 4), synth: :saw)
      ])
      """

      music = String.trim(music)

      for {call, expected} <- [
            {"without(#{music}, :kick)", [bass: [{0, 36}]]},
            {"only(#{music}, [:kick])", [kick: [{0, :own_note}, {1, :own_note}]]},
            {"without(#{music}, [:kick, :bass])", []}
          ] do
        {:ok, song} =
          load(ctx, "song(music: seq([#{call}, part(:bass, note(:e2, 1), synth: :saw)]))")

        assert {Code.eval_string("import Mx\n" <> call) |> elem(0) |> Mx.beats(), call} ==
                 {4, call}

        for {name, notes} <- expected, do: assert(played(events(song, name)) == notes)
        assert Enum.map(song.loops, & &1.name) -- [:bass] == Keyword.keys(expected) -- [:bass]
      end
    end

    @tag :tmp_dir
    test "without and only keep the tempo changes of the parts they leave out, and leave out a part's loop",
         ctx do
      {:ok, song} =
        load(ctx, """
        music = together([
          part(:kick, seq([rest(2), tempo(90), rest(2)]), synth: :kick),
          part(:hats, loop(1, fn _pass, _ -> steps("x", 1) end), synth: :closed_hihat),
          part(:bass, note(:c2, 4), synth: :saw)
        ])

        song(tempo: 120, music: seq([without(music, [:kick, :hats]), only(music, :bass)]))
        """)

      assert song.tempos.sections == {[{2, 90, 0}], [{2, 90, 0}]}
      assert Enum.map(song.loops, & &1.name) == [:bass]
    end

    @tag :tmp_dir
    test "swing moves each note to the beat its function returns, and leaves the length", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:lead, swing(seq(c4: 0.5, d4: 0.5), fn beat -> beat + 0.02 end)))"
        )

      assert played(events(song, :lead)) == [{0.02, 60}, {0.52, 62}]
      assert {:ok, %{beats: 1.0}} = Pass.events(hd(song.loops), 0)
    end

    @tag :tmp_dir
    test "random numbers drawn while the music is built are the same on every load", ctx do
      path =
        write(
          ctx,
          "song(music: part(:lead, seq(for _ <- 1..8, do: note(:c4, 1, amp: between(0.3, 0.6)))))"
        )

      {:ok, first} = Song.load(path)
      {:ok, second} = Song.load(path)

      assert events(first, :lead) == events(second, :lead)

      assert events(first, :lead)
             |> Enum.map(fn {_, _, opts} -> opts[:amp] end)
             |> Enum.uniq()
             |> length() > 1
    end

    @tag :tmp_dir
    test "the items of the outermost seq are sections, each a pass of every part", ctx do
      {:ok, song} =
        load(ctx, """
        first = together([part(:trombone, seq(c3: 2, e3: 2)), part(:flute, seq(r: 2, g5: 2))])
        second = together([part(:cello, seq(c3: 2, e3: 2)), part(:flute, seq(r: 2, a5: 2))])
        song(music: repeat(seq([first, second])))
        """)

      assert Enum.map(song.loops, &{&1.name, &1.passes}) == [
               trombone: nil,
               flute: nil,
               cello: nil
             ]

      flute = Enum.find(song.loops, &(&1.name == :flute))
      cello = Enum.find(song.loops, &(&1.name == :cello))

      assert {:ok, %{events: [{2, 79, _}], beats: 4}} = Pass.events(flute, 0)
      assert {:ok, %{events: [{2, 81, _}], beats: 4}} = Pass.events(flute, 1)
      assert {:ok, %{events: [{2, 79, _}], beats: 4}} = Pass.events(flute, 2)
      assert {:ok, %{events: [], beats: 4}} = Pass.events(cello, 0)
      assert {:ok, %{events: [{0, 48, _}, {2, 52, _}], beats: 4}} = Pass.events(cello, 1)
    end

    @tag :tmp_dir
    test "takes live audio and OSC settings", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:lead, seq(c4: 1)), live_audio: [mic: []], osc_to: {\"127.0.0.1\", 9000}, osc_from: 9001)"
        )

      assert [%{name: :mic, input: 1}] = song.live
      assert song.osc_to == {"127.0.0.1", 9000}
      assert song.osc_from == 9001
    end

    @tag :tmp_dir
    test "a song that defines a module loads again and again without a warning", ctx do
      path =
        write(
          ctx,
          "defmodule Mx.MusicTest.Tune do\n  import Mx\n  def melody, do: seq(c4: 1)\nend\n\nsong(music: part(:lead, Mx.MusicTest.Tune.melody()))"
        )

      warnings =
        capture_io(:stderr, fn -> for _ <- 1..5, do: assert({:ok, _} = Song.load(path)) end)

      assert warnings == ""
    end
  end

  describe "refusals" do
    @tag :tmp_dir
    test "an unknown note is refused with the line that made it", ctx do
      path = write(ctx, "song(music: part(:melody, seq([\n  note(:c4, 1),\n  note(:h4, 1)\n])))")

      assert Song.load(path) == {:error, "#{path}:5: unknown note h4"}
    end

    @tag :tmp_dir
    test "an option the part's synth does not have is refused, naming the note", ctx do
      path = write(ctx, "song(music: part(:guitar, note(:a4, 1, rooom: 1), synth: :guitar))")

      assert Song.load(path) ==
               {:error,
                "#{path}:3: part guitar: synth guitar has no option rooom, in note(69, 1, rooom: 1)"}
    end

    @tag :tmp_dir
    test "a value outside an option's range is refused, naming the range", ctx do
      path = write(ctx, "song(music: part(:lead, note(:c5, 1, vel: 1.5), synth: :flute))")

      assert Song.load(path) ==
               {:error,
                "#{path}:3: part lead: synth flute takes vel from 0 to 1, not 1.5, in note(72, 1, vel: 1.5)"}
    end

    @tag :tmp_dir
    test "a name an option does not take is refused, naming the ones it does", ctx do
      path =
        write(
          ctx,
          "song(music: part(:drums, seq([note(:c3, 1, bol: :ghe), note(:c3, 1, bol: :dha)]), synth: :tabla))"
        )

      assert Song.load(path) ==
               {:error,
                "#{path}:3: part drums: synth tabla takes bol na, tun, te, tas, ghe or ke, not dha, in note(48, 1, bol: :dha)"}
    end

    @tag :tmp_dir
    test "a change to the option that picks a synth's sound is refused, as it cannot change while the note sounds",
         ctx do
      path =
        write(
          ctx,
          "song(music: part(:drums, note(:c3, 2, bol: :ghe, changes: [{1, bol: :na}]), synth: :tabla))"
        )

      assert Song.load(path) ==
               {:error,
                "#{path}:3: part drums: bol cannot change once a sound plays, in note(48, 2, bol: :ghe, changes: [{1, [bol: :na]}])"}
    end

    @tag :tmp_dir
    test "a value outside its range in a part's defaults is refused", ctx do
      path =
        write(ctx, "song(music: part(:lead, note(:c5, 1), synth: :flute, defaults: [vel: -0.5]))")

      assert Song.load(path) ==
               {:error, "#{path}:3: part lead: synth flute takes vel from 0 to 1, not -0.5"}
    end

    @tag :tmp_dir
    test "a note outside any part is refused", ctx do
      path = write(ctx, "song(music: note(:c4, 1))")

      assert Song.load(path) ==
               {:error,
                "#{path}:3: every note plays in a part; put note(60, 1) in part(name, music, synth: ...)"}
    end

    @tag :tmp_dir
    test "two parts of one name together are refused", ctx do
      path =
        write(
          ctx,
          "song(music: together([part(:soprano, seq(c4: 1)), part(:soprano, seq(e4: 1))]))"
        )

      assert Song.load(path) == {:error, "#{path}:3: two parts named soprano play together"}
    end

    test "seq, together or at given a second argument that is no function of one argument is refused" do
      assert_raise ArgumentError,
                   "seq takes a list of music, or a collection and a function of one argument that makes each item, not :oops",
                   fn -> Mx.seq([1, 2], :oops) end

      assert_raise ArgumentError,
                   ~r/^together takes a list of music, or a collection and a function of one argument/,
                   fn -> Mx.together([1, 2], fn a, b -> a + b end) end

      assert_raise ArgumentError,
                   ~r/^at takes \{beat, value\} entries, a length and a function of one argument/,
                   fn -> Mx.at([{0, 1}], 4, :oops) end
    end

    test "form refuses a count below 1 and a name that is not an atom, naming the entry" do
      assert_raise ArgumentError,
                   "form takes section names, or names with counts from 1 up, not a: 0",
                   fn -> Mx.form([a: 0], fn _ -> Mx.rest(1) end) end

      assert_raise ArgumentError,
                   ~s(form takes section names, or names with counts from 1 up, not "a"),
                   fn -> Mx.form(["a"], fn _ -> Mx.rest(1) end) end
    end

    test "without and only refuse a name the music does not have" do
      music = Mx.together([Mx.part(:kick, Mx.steps("x", 1), synth: :kick)])

      assert_raise ArgumentError,
                   "without names part cowbel, which the music does not have",
                   fn ->
                     Mx.without(music, :cowbel)
                   end

      assert_raise ArgumentError, "only names part cowbel, which the music does not have", fn ->
        Mx.only(music, [:kick, :cowbel])
      end
    end

    @tag :tmp_dir
    test "music placed past the length of at is refused", ctx do
      path = write(ctx, "song(music: part(:offbeats, at([{2.5, note(:c4, 1)}], 2)))")

      assert Song.load(path) ==
               {:error, "#{path}:3: at places music at beat 2.5, past its length of 2"}
    end

    @tag :tmp_dir
    test "repeat without a count inside the music is refused", ctx do
      path =
        write(
          ctx,
          "song(music: together([part(:melody, seq(c4: 4)), part(:drone, repeat(seq(e4: 1)))]))"
        )

      assert Song.load(path) ==
               {:error,
                "#{path}:3: repeat without a count plays until mx stops, so it can only hold the whole of a song's music"}
    end

    @tag :tmp_dir
    test "a synth mx does not have is refused", ctx do
      path = write(ctx, "song(music: part(:lead, seq(c4: 1), synth: :kazoo))")

      assert Song.load(path) ==
               {:error, "#{path}:3: part lead uses synth kazoo, which mx does not have"}
    end
  end

  @tag :tmp_dir
  test "a tempo change in a section of its own starts the next section, and its changes are kept per section",
       ctx do
    path =
      write(
        ctx,
        "song(tempo: 100, music: seq([part(:a, seq(c4: 4)), tempo(140), part(:a, seq([rest(2), tempo(90, over: 4), rest(2)]))]))"
      )

    assert {:ok, song} = Song.load(path)

    assert song.tempos == %{
             sections: {[], [{0, 140, 0}, {2, 90, 4}]},
             lengths: {4, 4},
             forever: false
           }

    path = write(ctx, "song(tempo: 100, music: part(:a, seq(c4: 4)))")
    assert {:ok, %{tempos: nil}} = Song.load(path)
  end

  @tag :tmp_dir
  test "a tempo change a loop returns, one at the end of the music, and a tempo of 0 are refused",
       ctx do
    path = write(ctx, "song(music: part(:a, loop(1, fn _, _ -> seq([tempo(120), rest(1)]) end)))")
    assert {:ok, %{loops: [loop]}} = Song.load(path)
    assert {:error, message} = Pass.events(loop, 0)

    assert message =~
             "tempo changes every part, so it is written in the song's music, not returned by a loop"

    path = write(ctx, "song(music: seq([part(:a, seq(c4: 4)), tempo(140)]))")

    assert Song.load(path) ==
             {:error,
              "#{path}:3: a tempo change at the end of the music changes nothing; put it before the music it is for"}

    path = write(ctx, "song(music: seq([tempo(0), part(:a, seq(c4: 4))]))")
    assert Song.load(path) == {:error, "#{path}:3: tempo takes beats per minute above 0, not 0"}

    path = write(ctx, "song(music: seq([tempo(120, during: 4), part(:a, seq(c4: 4))]))")
    assert Song.load(path) == {:error, "#{path}:3: tempo has no option during; it takes over:"}
  end

  @tag :tmp_dir
  test "defaults and effects a part's synth does not take are refused, naming the part", ctx do
    path = write(ctx, "song(music: part(:lead, seq(c4: 1), defaults: [rooom: 1]))")
    assert Song.load(path) == {:error, "#{path}:3: part lead: synth tri has no option rooom"}

    path = write(ctx, "song(music: part(:lead, seq(c4: 1), fx: [reverb: [rooom: 1]]))")
    assert Song.load(path) == {:error, "#{path}:3: part lead: effect reverb has no option rooom"}

    path = write(ctx, "song(music: part(:lead, seq(c4: 1), fx: [chorus: [rooom: 1]]))")
    assert Song.load(path) == {:error, "#{path}:3: part lead: effect chorus has no option rooom"}

    path = write(ctx, "song(music: part(:lead, seq(c4: 1), fx: :chorus2))")
    assert Song.load(path) == {:error, "#{path}:3: part lead: mx has no effect chorus2"}
  end

  @tag :tmp_dir
  test "the opening of the Wachet auf chorale, as four parts together, plays once with no pass and no wait",
       ctx do
    body = """
    song(
      tempo: 72,
      music:
        together([
          part(:soprano, seq(eb4: 1, g4: 1, bb4: 1.5, bb4: 0.5, bb4: 1, bb4: 1, c5: 2), synth: :oboe),
          part(:alto, seq(bb3: 1, eb4: 1, g4: 1, f4: 1, g4: 1, f4: 1, g4: 1, f4: 1), synth: :clarinet),
          part(:tenor, seq(g3: 1, bb3: 1, eb4: 1, d4: 1, eb4: 1, bb3: 1, bb3: 1, a3: 1), synth: :viola),
          part(:bass, seq(eb3: 2.5, g3: 0.5, bb3: 0.5, ab3: 0.5, g3: 0.5, f3: 0.5, eb3: 0.5, d3: 0.5, eb3: 0.5, c3: 0.5, f3: 1), synth: :bassoon)
        ])
    )
    """

    path = write(ctx, body)
    {:ok, song} = Song.load(path)

    assert Enum.map(song.loops, &{&1.name, &1.synth, &1.passes}) ==
             [soprano: :oboe, alto: :clarinet, tenor: :viola, bass: :bassoon]
             |> Enum.map(fn {name, synth} -> {name, synth, 1} end)

    assert played(events(song, :soprano)) == [
             {0, 63},
             {1, 67},
             {2, 70},
             {3.5, 70},
             {4, 70},
             {5, 70},
             {6, 72}
           ]

    assert [{0, 51, [sustain: 2.5]} | _] = events(song, :bass)
  end

  describe "song files" do
    @tag :tmp_dir
    test "a file with a syntax error is refused, naming its line", ctx do
      path = write(ctx, "song(music: part(:a, seq(c4: 1))))")
      assert {:error, message} = Song.load(path)
      assert message =~ Path.basename(path) <> ":3"
    end

    @tag :tmp_dir
    test "a file that does not end with a song is refused", ctx do
      path = write(ctx, ":ok")
      assert Song.load(path) == {:error, "#{path} does not end with a song"}
    end

    @tag :tmp_dir
    test "a file that defines a module and no song reads as a module, and loads as no song",
         ctx do
      path = write(ctx, "defmodule MusicTest.Notes do\n  def bar, do: [60, 62]\nend")
      assert Song.read(path) == :module
      assert Song.load(path) == {:error, "#{path} does not end with a song"}
      assert apply(MusicTest.Notes, :bar, []) == [60, 62]
    end

    @tag :tmp_dir
    test "a module that does not compile is refused, naming its line", ctx do
      path = write(ctx, "defmodule MusicTest.Broken do\n  def bar, do: [60, 62\nend")
      assert {:error, message} = Song.read(path)
      assert message =~ Path.basename(path)
    end

    @tag :tmp_dir
    test "a file that defines no module and no song does not read as a module", ctx do
      path = write(ctx, "x = 1")
      assert Song.read(path) == {:error, "#{path} does not end with a song"}
    end
  end

  describe "effects" do
    @tag :tmp_dir
    test "a part's effects load as a chain, from one effect, a list, or a list with options",
         ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:a, seq(c4: 1), fx: :reverb),
          part(:b, seq(c4: 1), fx: [:echo, :reverb]),
          part(:c, seq(c4: 1), fx: [echo: [phase: 0.25], reverb: []]),
          part(:d, seq(c4: 1))
        ]))
        """)

      assert Enum.map(song.loops, & &1.fx) == [
               [reverb: []],
               [echo: [], reverb: []],
               [echo: [phase: 0.25], reverb: []],
               []
             ]
    end

    @tag :tmp_dir
    test "the buses of an effect, an effect used as a synth, and fx: that is no effect are refused",
         ctx do
      path = write(ctx, "song(music: part(:a, seq(c4: 1), fx: [reverb: [out_bus: 2]]))")
      assert Song.load(path) == {:error, "#{path}:3: part a: effect reverb has no option out_bus"}

      path = write(ctx, "song(music: part(:a, seq(c4: 1), synth: :fx_reverb))")

      assert Song.load(path) ==
               {:error, "#{path}:3: part a uses synth fx_reverb, which mx does not have"}

      path = write(ctx, "song(music: part(:a, seq(c4: 1), fx: \"reverb\"))")
      assert {:error, message} = Song.load(path)
      assert message =~ "part a: fx: takes an effect or a list of effects"
    end
  end

  describe "options per note" do
    @tag :tmp_dir
    test "a chord takes a list of values for an option, one per note, beside single values and the part's defaults",
         ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:a, note([45, 52, 57], 1, vel: [0.7, 0.5, 0.4]), synth: :guitar, defaults: [amp: 0.5]))"
        )

      assert events(song, :a) == [
               {0, 45, [vel: 0.7, sustain: 1, amp: 0.5]},
               {0, 52, [vel: 0.5, sustain: 1, amp: 0.5]},
               {0, 57, [vel: 0.4, sustain: 1, amp: 0.5]}
             ]
    end

    @tag :tmp_dir
    test "the values follow the notes as written, whatever order the strum plays them in", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:a, seq([note([57, 45, 52], 0, vel: [0.4, 0.7, 0.5], strum: 0.05), rest(1)]), synth: :guitar))"
        )

      assert events(song, :a) == [
               {0, 45, [vel: 0.7]},
               {0.05, 52, [vel: 0.5]},
               {0.1, 57, [vel: 0.4]}
             ]
    end

    @tag :tmp_dir
    test "a piano chord holds the pedal down on the notes that ask for it", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:a, seq([note([48, 52, 55], 0, pedal: [1, 0, 0]), rest(1)]), synth: :piano))"
        )

      assert events(song, :a) == [{0, 48, [pedal: 1]}, {0, 52, [pedal: 0]}, {0, 55, [pedal: 0]}]
    end

    @tag :tmp_dir
    test "a list with more or fewer values than the notes, or a list for one note, is refused",
         ctx do
      path =
        write(
          ctx,
          "song(music: part(:a, note([45, 52, 57], 1, vel: [0.7, 0.5]), synth: :guitar))"
        )

      assert {:error, message} = Song.load(path)
      assert message =~ "gives vel 2 values for 3 notes"

      path = write(ctx, "song(music: part(:a, note(45, 1, vel: [0.7, 0.5]), synth: :guitar))")
      assert {:error, message} = Song.load(path)
      assert message =~ "gives vel a list for one note"
    end

    @tag :tmp_dir
    test "guitar refuses tremolo, which only the bandolim takes", ctx do
      path = write(ctx, "song(music: part(:a, note(45, 1, tremolo: 4), synth: :guitar))")
      assert {:error, message} = Song.load(path)
      assert message =~ "synth guitar has no option tremolo"
    end

    @tag :tmp_dir
    test "a sample does not take the part's defaults", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:a, sample({:sonic_pi, :loop_amen}, 1), defaults: [amp: 0.5]))"
        )

      assert [{0, {:sample, {:sonic_pi, :loop_amen}, _}, []}] = events(song, :a)
    end
  end

  describe "live audio" do
    @tag :tmp_dir
    test "loads each live audio with its input, channels, options and effects", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:a, seq(c4: 1)), live_audio: [mic: [], guitar: [input: 2, stereo: true, amp: 0.5, pan: -0.5, fx: :reverb]])"
        )

      assert [mic, guitar] = song.live
      assert mic == %Song.Live{name: :mic, input: 1, stereo: false, opts: [], fx: []}

      assert guitar == %Song.Live{
               name: :guitar,
               input: 2,
               stereo: true,
               opts: [amp: 0.5, pan: -0.5],
               fx: [reverb: []]
             }
    end

    @tag :tmp_dir
    test "an option, input, name or effect live audio cannot take is refused", ctx do
      for {live, message} <- [
            {"[mic: [gain: 2]]", "live_audio mic has no option gain"},
            {"[mic: [input: 0]]", "live_audio mic: input must be 1 or more, not 0"},
            {"[mic: [], mic: [input: 2]]", "describes live_audio mic twice"},
            {"[mic: [fx: :reverbb]]", "live_audio mic: mx has no effect reverbb"}
          ] do
        path = write(ctx, "song(music: part(:a, seq(c4: 1)), live_audio: #{live})")
        assert {:error, refused} = Song.load(path)
        assert refused =~ message
      end
    end

    @tag :tmp_dir
    test "live audio synths are not synths a part can play", ctx do
      path = write(ctx, "song(music: part(:a, seq(c4: 1), synth: :live_audio_mono))")

      assert Song.load(path) ==
               {:error, "#{path}:3: part a uses synth live_audio_mono, which mx does not have"}
    end
  end

  describe "loops" do
    @tag :tmp_dir
    test "a loop runs its function each pass, so the hats double on their fourth pass", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: part(:hats, loop(4, fn pass, _ ->
          steps(if(pass == 3, do: "xxxxxxxx", else: "x.x.x.x."), 0.5)
        end), synth: :closed_hihat))
        """)

      assert [%{name: :hats, passes: nil} = loop] = song.loops
      assert {:ok, %{events: quarters, beats: 4}} = Pass.events(loop, 0)
      assert length(quarters) == 4
      assert {:ok, %{events: eighths, beats: 4}} = Pass.events(loop, 3)
      assert length(eighths) == 8
    end

    @tag :tmp_dir
    test "beside other music a loop plays until it ends, and the song ends with it", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:bass, seq(c4: 32)),
          part(:drums, loop(4, fn _, _ -> steps("x...", 1) end), synth: :kick)
        ]))
        """)

      drums = Enum.find(song.loops, &(&1.name == :drums))
      assert drums.passes == 1
      assert {:ok, %{events: hits, beats: 32}} = Pass.events(drums, 0)
      assert Enum.map(hits, &elem(&1, 0)) == [0, 4, 8, 12, 16, 20, 24, 28]
    end

    @tag :tmp_dir
    test "a loop's last pass is cut where the music beside it ends", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:bass, seq(c3: 8)),
          part(:drums, loop(3, fn _, _ -> steps("xxx", 1) end), synth: :kick)
        ]))
        """)

      drums = Enum.find(song.loops, &(&1.name == :drums))
      assert {:ok, %{events: hits, beats: 8}} = Pass.events(drums, 0)
      assert Enum.map(hits, &elem(&1, 0)) == [0, 1, 2, 3, 4, 5, 6, 7]
    end

    @tag :tmp_dir
    test "times: plays a number of passes, and the song ends after them", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:drums, loop(16, fn _, _ -> steps(\"x\", 1) end, times: 4), synth: :kick))"
        )

      assert [%{passes: 1} = drums] = song.loops
      assert {:ok, %{events: hits, beats: 64}} = Pass.events(drums, 0)
      assert Enum.map(hits, &elem(&1, 0)) == [0, 16, 32, 48]
    end

    @sections """
    defmodule Sections do
      def section(chord), do: together([
        part(:bass, note(chord, 8)),
        part(:guitar, loop(4, fn pass, _ -> note(:c4, 1, amp: pass / 10) end))
      ])
    end

    song(music: seq([Sections.section(:c3), Sections.section(:f3)]))
    """

    @tag :tmp_dir
    test "a part's loop counts its passes on from one section into the next", ctx do
      {:ok, song} = load(ctx, @sections)

      guitar = Enum.find(song.loops, &(&1.name == :guitar))
      assert {:ok, %{events: first}} = Pass.events(guitar, 0)
      assert {:ok, %{events: second}} = Pass.events(guitar, 1)
      assert Enum.map(first, &{elem(&1, 0), elem(&1, 2)[:amp]}) == [{0, 0.0}, {4, 0.1}]
      assert Enum.map(second, &{elem(&1, 0), elem(&1, 2)[:amp]}) == [{0, 0.2}, {4, 0.3}]
    end

    @tag :tmp_dir
    test "a pass whose music is longer than the loop is refused with the part's name and line",
         ctx do
      {:ok, song} =
        load(ctx, """
        song(music: part(:drums, loop(16, fn _, _ ->
          rest(18)
        end), synth: :kick))
        """)

      [drums] = song.loops
      assert {:error, message} = Pass.events(drums, 0)
      assert message =~ "loop drums made 18 beats of music in a pass of 16"
      assert message =~ ~r/song_\d+\.exs:3: loop drums made/
    end

    @tag :tmp_dir
    test "a pass that raises names the part and the line, and the next pass plays", ctx do
      {:ok, song} =
        load(ctx, """
        song(music: part(:lead, loop(1, fn pass, _ ->
          if pass == 1, do: note(:nope, 1), else: note(:c4, 1)
        end)))
        """)

      [lead] = song.loops
      assert {:error, message} = Pass.events(lead, 1)
      assert message =~ ~r/song_\d+\.exs:3: part lead: unknown note nope/
      assert {:ok, %{events: [{0, 60, _}]}} = Pass.events(lead, 2)
    end

    @tag :tmp_dir
    test "a pass reads the inputs, nil for what nothing sent", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:bass, loop(1, fn _, inputs -> note(:c2, 1, amp: inputs.cc[74] || 0) end), synth: :saw))"
        )

      [bass] = song.loops
      assert {:ok, %{events: [{0, 36, opts}]}} = Pass.events(bass, 0, inputs: %{{:cc, 74} => 64})
      assert opts[:amp] == 64
      assert {:ok, %{events: [{0, 36, opts}]}} = Pass.events(bass, 0)
      assert opts[:amp] == 0
    end

    @tag :tmp_dir
    test "random numbers in a pass are seeded from the part and the pass", ctx do
      body =
        "song(music: part(:lead, loop(1, fn _, _ -> note(pick([:c4, :d4, :e4, :g4, :a4]), 1) end)))"

      {:ok, first} = load(ctx, body)
      {:ok, second} = load(ctx, body)

      notes = fn song -> for pass <- 0..9, do: Pass.events(hd(song.loops), pass) end
      assert notes.(first) == notes.(second)
      assert notes.(first) |> Enum.uniq() |> length() > 1
    end

    @tag :tmp_dir
    test "a loop on: plays a pass for each input, with what arrived", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:keys, loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note)))"
        )

      assert [%{on: :midi_note, passes: nil} = keys] = song.loops

      assert {:ok, %{events: [{0, 64, _}]}} =
               Pass.events(keys, 0, trigger: %{note: 64, velocity: 100})
    end

    @tag :tmp_dir
    test "a loop beside a loop on: plays until mx stops", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: together([part(:a, loop(1, fn _, _ -> note(60, 1) end)), part(:keys, loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note))]))"
        )

      assert [%{name: :a, passes: nil} = a, %{name: :keys}] = song.loops
      assert {:ok, %{events: [{0, 60, _}]}} = Pass.events(a, 5)
    end

    @tag :tmp_dir
    test "meditation's sam bell rings on every cycle of the gat and the first beat of shanti",
         ctx do
      {:ok, song} =
        load(ctx, """
        sam = fn music -> part(:sam, music, synth: :glockenspiel, defaults: [pan: -0.1]) end
        bell = note(:d6, 16, vel: 0.5, amp: 4)

        song(music: seq([
          part(:drone, note(:d3, 64)),
          together([part(:drone, note(:d3, 128)), sam.(loop(16, fn _, _ -> bell end))]),
          together([part(:drone, note(:d3, 32)), sam.(bell)])
        ]))
        """)

      sam = Enum.find(song.loops, &(&1.name == :sam))

      beats = fn pass ->
        pass
        |> then(&Pass.events(sam, &1))
        |> elem(1)
        |> Map.fetch!(:events)
        |> Enum.map(&elem(&1, 0))
      end

      assert beats.(0) == []
      assert beats.(1) == [0, 16, 32, 48, 64, 80, 96, 112]
      assert beats.(2) == [0]
    end

    @tag :tmp_dir
    test "a loop outside a part, inside swing, or before more music is refused", ctx do
      assert {:error, message} = load(ctx, "song(music: loop(4, fn _, _ -> rest(4) end))")
      assert message =~ "every loop plays in a part"

      assert {:error, message} =
               load(ctx, "song(music: part(:a, swing(loop(4, fn _, _ -> rest(4) end), & &1)))")

      assert message =~ "swing cannot hold a loop"

      assert {:error, message} =
               load(
                 ctx,
                 "song(music: part(:a, seq([loop(4, fn _, _ -> rest(4) end), note(:c4, 1)])))"
               )

      assert message =~ "music after a loop with no times: never plays"
    end
  end

  describe "samples, MIDI, OSC, shared values and changes" do
    @tag :tmp_dir
    test "a sample plays at its beat, and the song names it to load before playing", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:drums, seq([sample({:sonic_pi, :bd_haus}, 1), sample({:sonic_pi, :bd_haus}, 1)])))"
        )

      [drums] = song.loops
      assert [path] = drums.samples
      assert path =~ "bd_haus"

      assert {:ok,
              %{
                events: [
                  {0, {:sample, {:sonic_pi, :bd_haus}, ^path}, []},
                  {1, {:sample, {:sonic_pi, :bd_haus}, ^path}, []}
                ],
                beats: 2
              }} =
               Pass.events(drums, 0)
    end

    @tag :tmp_dir
    test "a sample mx cannot find is refused with its line", ctx do
      assert {:error, message} =
               load(ctx, "song(music: part(:drums,\n  sample({:sonic_pi, :no_such_sample}, 0)))")

      assert message =~ ~r/song_\d+\.exs:4: .*no_such_sample/
    end

    @tag :tmp_dir
    test "a loop names a sample only in the passes that play it", ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:drums, loop(1, fn pass, _ -> if(pass == 2, do: sample({:sonic_pi, :bd_haus}, 1), else: rest(1)) end)))"
        )

      [drums] = song.loops
      assert drums.samples == []
      assert {:ok, %{events: []}} = Pass.events(drums, 1)

      assert {:ok, %{events: [{0, {:sample, {:sonic_pi, :bd_haus}, _}, []}]}} =
               Pass.events(drums, 2)
    end

    @tag :tmp_dir
    test "midi, midi_cc, osc and set are steps at their beats", ctx do
      {:ok, song} =
        load(ctx, """
        song(osc_to: {"127.0.0.1", 9000}, music: part(:synth, seq([
          midi(60, 2, velocity: 90),
          midi_cc(74, 64),
          osc("/hello", [1, "a"]),
          set(:root, 40),
          midi(:e4, 1)
        ]), midi: "mx test port"))
        """)

      [synth] = song.loops
      assert synth.midi == "mx test port"

      assert {:ok, %{events: events, beats: 3}} = Pass.events(synth, 0)

      assert events == [
               {0, {:midi_note, 60}, [channel: 1, length: 2, velocity: 90]},
               {2, {:midi_cc, 74, 64}, [channel: 1]},
               {2, {:osc, "/hello", [1, "a"]}, []},
               {2, {:set, :root, 40}, []},
               {2, {:midi_note, 64}, [velocity: 100, channel: 1, length: 1]}
             ]
    end

    @tag :tmp_dir
    test "a sample file that does not exist, or one of the pack before it is downloaded, is refused",
         ctx do
      path = write(ctx, "song(music: part(:drums, sample(\"/missing.wav\", 1)))")
      assert {:error, message} = Song.load(path)
      assert message =~ "sample file /missing.wav does not exist"

      path = write(ctx, "song(music: part(:pad, sample({:sonic_pi, :ambi_choir}, 1)))")
      assert {:error, message} = Song.load(path)
      assert message =~ "sample ambi_choir"
      assert message =~ "run mix mx.samples.download sonic_pi"
    end

    @tag :tmp_dir
    test "a sample file mx cannot read is refused when the song loads, naming the file and why",
         ctx do
      kick = Path.join(ctx.tmp_dir, "kick.wav")
      File.write!(kick, "not a sound\n")
      path = write(ctx, "song(music: part(:drums, sample(#{inspect(kick)}, 1)))")
      assert {:error, message} = Song.load(path)
      assert message =~ "sample file #{kick} cannot play: it is not a FLAC, WAV or AIFF file"
    end

    @tag :tmp_dir
    test "an option samples do not have is refused", ctx do
      path = write(ctx, "song(music: part(:drums, sample({:sonic_pi, :bd_haus}, 1, relase: 1)))")
      assert {:error, message} = Song.load(path)
      assert message =~ "samples have no option relase"
    end

    @tag :tmp_dir
    test "a MIDI option it does not have, or a value out of range, is refused", ctx do
      for {step, message} <- [
            {"midi(60, 1, velocty: 1)", "midi has no option velocty"},
            {"midi(60, 1, velocity: 128)", "midi velocity must be from 0 to 127, not 128"},
            {"midi(60, 1, channel: 17)", "midi channel must be from 1 to 16, not 17"},
            {"midi(60, 0)", "midi lasts more than 0 beats"},
            {"midi_cc(128, 1)", "midi_cc number must be from 0 to 127, not 128"},
            {"midi_cc(1, -1)", "midi_cc value must be from 0 to 127, not -1"}
          ] do
        path =
          write(ctx, "song(music: part(:a, seq([#{step}, rest(1)]), midi: \"mx test port\"))")

        assert {:error, refused} = Song.load(path)
        assert refused =~ message
      end
    end

    @tag :tmp_dir
    test "an OSC address or argument OSC cannot carry is refused", ctx do
      for {step, message} <- [
            {"osc(\"hi\")", "osc address must be a string starting with /, not \"hi\""},
            {"osc(\"/hi\", [:a])", "osc arguments must be numbers or strings, not :a"}
          ] do
        path =
          write(
            ctx,
            "song(osc_to: {\"localhost\", 9000}, music: part(:a, seq([#{step}, rest(1)])))"
          )

        assert {:error, refused} = Song.load(path)
        assert refused =~ message
      end
    end

    @tag :tmp_dir
    test "on: that names no input is refused", ctx do
      path = write(ctx, "song(music: part(:a, loop(fn _, _ -> rest(1) end, on: :keyboard)))")
      assert {:error, message} = Song.load(path)

      assert message =~
               "a loop with no length takes on: :midi_note, :midi_cc or {:osc, address}, not :keyboard"
    end

    @tag :tmp_dir
    test "osc with no osc_to in the song is refused", ctx do
      assert {:error, message} = load(ctx, "song(music: part(:lights, osc(\"/scene\", [1])))")
      assert message =~ "osc needs osc_to: {host, port} in the song"
    end

    @tag :tmp_dir
    test "a note carries its own changes, and refuses one that cannot change once it plays",
         ctx do
      {:ok, song} =
        load(
          ctx,
          "song(music: part(:lead, note(:a4, 4, changes: [{1, note: :c5, note_slide: 0.1}]), synth: :flute))"
        )

      [lead] = song.loops

      assert {:ok, %{events: [{0, 69, opts}, {1, {:control, {:sounds, [0]}, :flute}, change}]}} =
               Pass.events(lead, 0)

      refute Keyword.has_key?(opts, :changes)
      assert change == [note: 72, note_slide: 0.1]

      assert {:error, message} =
               load(
                 ctx,
                 "song(music: part(:lead,\n  note(:a4, 4, changes: [{1, release: 2}]), synth: :flute))"
               )

      assert message =~ ~r/song_\d+\.exs:3: part lead: release cannot change once a sound plays/
    end

    @tag :tmp_dir
    test "change changes every sound of the part it names, or one of its effects, wherever it is written",
         ctx do
      {:ok, song} =
        load(ctx, """
        song(music: together([
          part(:lead, note(:c4, 8), synth: :saw, fx: [reverb: []]),
          part(:conductor, seq([rest(2), change(:lead, cutoff: 80, cutoff_slide: 2), rest(2), change({:lead, :reverb}, mix: 0)]))
        ]))
        """)

      lead = Enum.find(song.loops, &(&1.name == :lead))
      assert lead.music.changed

      assert {:ok,
              %{
                events: [
                  {0, 60, _},
                  {2, {:control, :part, :saw}, [cutoff: 80, cutoff_slide: 2]},
                  {4, {:control, {:effect, 0}, _}, [mix: 0]}
                ]
              }} =
               Pass.events(lead, 0)
    end

    @tag :tmp_dir
    test "a change to a part or effect the song does not have is refused", ctx do
      assert {:error, message} =
               load(
                 ctx,
                 "song(music: part(:lead, seq([note(:c4, 1), change({:lead, :echo}, mix: 0)])))"
               )

      assert message =~ "change names effect echo, which part lead does not have"

      assert {:error, message} =
               load(ctx, "song(music: part(:lead, seq([note(:c4, 1), change(:nobody, amp: 0)])))")

      assert message =~
               ~r/song_\d+\.exs:3: change names part nobody, which the song does not have/
    end
  end

  test "pitch is a note's number, and note always makes a note" do
    assert Mx.pitch(:e5) == 76
    assert %Mx.Music.Note{pitch: 76, beats: 1} = Mx.note(:e5, 1)
  end

  defp events(song, name) do
    loop = Enum.find(song.loops, &(&1.name == name))
    {:ok, %{events: events}} = Pass.events(loop, 0)
    events
  end

  defp played(events), do: Enum.map(events, fn {beat, note, _opts} -> {beat, note} end)

  @tag :tmp_dir
  test "a song states its meter as whole beats to a bar, 4 unless given, and a meter of 0 is refused",
       ctx do
    assert {:ok, %{meter: 3}} = load(ctx, "song(meter: 3, music: part(:a, seq(c4: 3)))")
    assert {:ok, %{meter: 4}} = load(ctx, "song(music: part(:a, seq(c4: 4)))")

    for meter <- ["0", "2.5", ":waltz"] do
      path = write(ctx, "song(meter: #{meter}, music: part(:a, seq(c4: 4)))")

      assert Song.load(path) ==
               {:error,
                "#{path}:3: song takes meter: as whole beats to a bar above 0, not #{meter}"}
    end
  end

  defp load(ctx, body), do: ctx |> write(body) |> Song.load()

  defp write(%{tmp_dir: dir}, body) do
    path = Path.join(dir, "song_#{System.unique_integer([:positive])}.exs")
    File.write!(path, "import Mx\n\n" <> body <> "\n")
    path
  end
end
