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
