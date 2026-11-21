defmodule Mx.SongModuleTest do
  use ExUnit.Case, async: true

  alias Mx.{Pass, Song}

  @moduletag :tmp_dir

  test "a module that uses Mx.Song is the song, its parts playing with the options they declare",
       ctx do
    {:ok, song} =
      load(ctx, """
      defmodule #{name(ctx)} do
        use Mx.Song, tempo: 92

        part :kick, synth: :kick, fx: [level: [amp: 0.6]]
        part :lead, synth: :oboe

        def kick, do: steps(~MX"x..x"s, 0.25)

        def song do
          seq([
            part(:kick, kick()),
            together([part(:kick, kick()), part(:lead, delay(note(:c4, 1), 1))])
          ])
        end
      end
      """)

    assert song.tempo == 92

    assert [%{name: :kick, synth: :kick, fx: [level: [amp: 0.6]]} = kick, %{name: :lead} = lead] =
             song.loops

    assert {:ok, %{events: [{0, :own_note, _}, {0.75, :own_note, _}], beats: 1.0}} =
             Pass.events(kick, 0)

    assert {:ok, %{events: [{1, 60, _}], beats: 2}} = Pass.events(lead, 1)
  end

  test "a part that is not declared does not compile, and names its line", ctx do
    path =
      write(ctx, """
      defmodule #{name(ctx)} do
        use Mx.Song

        part :kick, synth: :kick

        def song, do: part(:snare, steps("x", 1))
      end
      """)

    assert {:error, message} = Song.load(path)
    assert message =~ "#{path}:6: part snare is not declared"
  end

  test "together takes declared parts by name, each on its declared synth, beside notes and music",
       ctx do
    {:ok, song} =
      load(ctx, """
      defmodule #{name(ctx)} do
        use Mx.Song

        part :lead, synth: :oboe
        part :bass, synth: :bassoon

        def song do
          together([lead: seq(c4: 1)] ++ [bass: seq(c2: 1)])
        end
      end
      """)

    assert [%{name: :lead, synth: :oboe} = lead, %{name: :bass, synth: :bassoon} = bass] =
             song.loops

    assert {:ok, %{events: [{0, 60, _}]}} = Pass.events(lead, 0)
    assert {:ok, %{events: [{0, 36, _}]}} = Pass.events(bass, 0)

    {:ok, song} =
      load(ctx, """
      defmodule #{name(ctx)}Chord do
        use Mx.Song

        part :lead, synth: :oboe
        part :bass, synth: :bassoon

        def song, do: together([part(:lead, together(c4: 4, e4: 4)), bass: seq(c2: 4)])
      end
      """)

    assert [lead, _bass] = song.loops
    assert {:ok, %{events: [{0, 60, _}, {0, 64, _}], beats: 4}} = Pass.events(lead, 0)
  end

  test "together refuses a part name that is not declared, naming the file and line", ctx do
    path =
      write(ctx, """
      defmodule #{name(ctx)} do
        use Mx.Song

        part :lead, synth: :oboe
        part :bass, synth: :bassoon

        def song do
          together(lead: seq(c4: 1), drums: seq(c2: 1))
        end
      end
      """)

    assert {:error, message} = Song.load(path)

    assert message ==
             "#{path}:8: part drums is not declared; declare it with part :drums, synth: ..."
  end

  test "a script song's together refuses a part name, saying to write part", ctx do
    path = write(ctx, "import Mx\n\nsong(music: together(lead: seq(c4: 1)))\n")

    assert {:error, message} = Song.load(path)
    assert message =~ "#{path}:3: "
    assert message =~ "part(:lead, music, synth: ...)"
  end

  test "a kit plays one pattern on the parts its strokes name, each silent where it has none",
       ctx do
    kit = fn body ->
      {:ok, song} =
        load(ctx, """
        defmodule #{name(ctx)}#{System.unique_integer([:positive])} do
          use Mx.Song

          part :thumb, synth: :pandeiro_thumb
          part :heel, synth: :pandeiro_heel

          kit :drum,
            o: [part: :thumb, vel: 0.75],
            h: [part: :heel, vel: 0.55],
            both: [:o, :h]

          def song, do: #{body}
        end
        """)

      for loop <- song.loops, into: %{} do
        {:ok, %{events: events, beats: beats}} = Pass.events(loop, 0)
        {loop.name, {for({beat, _, opts} <- events, do: {beat, opts[:vel]}), beats}}
      end
    end

    assert kit.(~s|kit(:drum, ~MX"o h h o", 0.25)|) == %{
             thumb: {[{0, 0.75}, {0.75, 0.75}], 1.0},
             heel: {[{0.25, 0.55}, {0.5, 0.55}], 1.0}
           }

    assert %{thumb: {[{0, 0.75}], _}, heel: {[{0, 0.55}], _}} =
             kit.(~s|kit(:drum, ~MX"both _", 0.25)|)

    assert %{heel: {[{0.25, 0.9}], _}} =
             kit.(~s|kit(:drum, ~MX"o >h", 0.25, accent: [vel: 0.9])|)

    assert %{heel: {[{0.25, _}, {0.375, _}], 1.0}} = kit.(~s|kit(:drum, ~MX"o [h h] _ _", 0.25)|)

    assert %{thumb: {[{0, _}], 1.0}, heel: {[{0.5, _}], 1.0}} =
             kit.(~s|kit(:drum, ~MX"o.h."s, 0.25)|)

    module = Module.concat([name(ctx) <> "Silent"])

    {:ok, _song} =
      load(ctx, """
      defmodule #{module} do
        use Mx.Song

        part :thumb, synth: :pandeiro_thumb
        part :heel, synth: :pandeiro_heel

        kit :drum, o: [part: :thumb, vel: 0.75], h: [part: :heel, vel: 0.55]

        def silent_heel, do: kit(:drum, ~MX"o o", 0.25)
        def song, do: silent_heel()
      end
      """)

    music = module.silent_heel()
    assert Mx.beats(music) == 0.5

    assert %Mx.Music.Together{items: [%{name: :thumb}, %{name: :heel, music: heel}]} = music
    assert Mx.beats(heel) == 0.5
    assert %Mx.Music.Seq{items: [%Mx.Music.Rest{}, %Mx.Music.Rest{}]} = heel
  end

  test "a kit refuses a word that is no stroke, and plays beside parts, not inside one", ctx do
    path = fn body ->
      write(ctx, """
      defmodule #{name(ctx)}#{System.unique_integer([:positive])} do
        use Mx.Song

        part :thumb, synth: :pandeiro_thumb
        part :heel, synth: :pandeiro_heel

        kit :drum, o: [part: :thumb, vel: 0.75], h: [part: :heel, vel: 0.55]

        def song, do: #{body}
      end
      """)
    end

    assert {:error, message} = Song.load(path.(~s|kit(:drum, ~MX"o q", 0.25)|))
    assert message =~ "kit drum has no stroke q"

    assert {:error, message} = Song.load(path.(~s|part(:thumb, kit(:drum, ~MX"o", 1))|))
    assert message =~ "a kit plays beside parts"
  end

  test "a kit naming a part or a stroke that is not declared, and a kit declared twice, do not compile",
       ctx do
    for {kits, refusal} <- [
          {"kit :drum, s: [part: :slap, vel: 0.8]",
           ~r/:5: kit drum names part slap, which is not declared/},
          {"kit :drum, both: [:o, :h]",
           ~r/:5: kit drum's stroke both names stroke o, which the kit does not have/},
          {"kit :drum, o: [part: :thumb]\n  kit :drum, o: [part: :thumb]",
           ~r/:6: kit drum is declared twice/}
        ] do
      path =
        write(ctx, """
        defmodule #{name(ctx)}#{System.unique_integer([:positive])} do
          use Mx.Song

          part :thumb, synth: :pandeiro_thumb
          #{kits}

          def song, do: kit(:drum, ~MX"o", 1)
        end
        """)

      assert {:error, message} = Song.load(path)
      assert message =~ refusal
    end

    path =
      write(ctx, """
      defmodule #{name(ctx)}Undeclared do
        use Mx.Song

        part :thumb, synth: :pandeiro_thumb

        def song, do: kit(:drum, ~MX"o", 1)
      end
      """)

    assert {:error, message} = Song.load(path)
    assert message =~ ":6: kit drum is not declared"
  end

  test "a part declared twice, and a module with no song, do not compile", ctx do
    twice = """
    defmodule #{name(ctx)} do
      use Mx.Song

      part :kick, synth: :kick
      part :kick, synth: :snare

      def song, do: part(:kick, steps("x", 1))
    end
    """

    assert {:error, message} = load(ctx, twice)
    assert message =~ "part kick is declared twice"

    assert {:error, message} = load(ctx, "defmodule #{name(ctx)}.Empty do\n  use Mx.Song\nend")
    assert message =~ "returns its music from song/0"
  end

  test "a file with two modules that use Mx.Song is refused", ctx do
    one = fn suffix ->
      """
      defmodule #{name(ctx)}.#{suffix} do
        use Mx.Song
        part :kick, synth: :kick
        def song, do: part(:kick, steps("x", 1))
      end
      """
    end

    path = write(ctx, one.("One") <> one.("Two"))

    assert Song.load(path) ==
             {:error, "#{path} holds two songs, #{name(ctx)}.One and #{name(ctx)}.Two"}
  end

  defp name(ctx), do: "SongModule#{:erlang.phash2(ctx.test)}"

  defp load(ctx, body), do: ctx |> write(body) |> Song.load()

  defp write(%{tmp_dir: dir}, body) do
    path = Path.join(dir, "song_#{System.unique_integer([:positive])}.exs")
    File.write!(path, body)
    path
  end
end
