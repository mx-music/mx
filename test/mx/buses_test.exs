defmodule Mx.BusesTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000

  defp write(ctx, song) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\n" <> song <> "\n")
    path
  end

  defp load(ctx, song), do: Mx.Song.load(write(ctx, song))

  # The left side of a render of a song.
  defp render(ctx, song, opts \\ [ring_out: false]) do
    path = write(ctx, song)
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, opts) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    for <<left::little-float-32, _right::little-float-32 <- data>>, do: left
  end

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()
  defp db(level), do: 20 * :math.log10(level)
  defp from(samples, seconds), do: Enum.drop(samples, round(seconds * @rate))

  defp between(samples, from, to) do
    Enum.slice(samples, round(from * @rate)..(round(to * @rate) - 1))
  end

  @two "together([part(:a, note(:a2, 1), synth: :saw, OPTS), part(:b, note(:e4, 1), synth: :tri, OPTS)])"

  @tag :engine
  test "two parts sending into one reverb sound as each through a reverb of its own", ctx do
    own = String.replace(@two, "OPTS", "fx: [reverb: [mix: 0.5]]")
    sent = String.replace(@two, "OPTS", "send: [room: 1]")
    own = render(ctx, "song(tempo: 120, music: seq([#{own}, rest(2)]))")

    shared =
      render(ctx, "song(tempo: 120, buses: [room: [reverb: []]], music: seq([#{sent}, rest(2)]))")

    apart = Enum.zip_with(own, shared, &(&1 * 2 - &2))
    assert peak(own) > 0.05
    assert db(peak(apart) / peak(shared)) < -90
  end

  @tag :engine
  test "a send at 0 renders the same samples as no send, and so does a song with a bus nothing sends into",
       ctx do
    plain = String.replace(@two, ", OPTS", "")
    zero = String.replace(@two, "OPTS", "send: [room: 0]")
    dry = render(ctx, "song(tempo: 120, music: #{plain})")
    assert render(ctx, "song(tempo: 120, buses: [room: [reverb: []]], music: #{zero})") == dry
    assert render(ctx, "song(tempo: 120, buses: [room: [reverb: []]], music: #{plain})") == dry
  end

  @tag :engine
  test "a change of a part's send before one hit and after it echoes that hit only", ctx do
    hits = "part(:tom, seq(for _ <- 1..4, do: seq([note(:a2, 0.25), rest(1.75)])), synth: :tri)"
    throw = "at([{1.9, change(:tom, send: [tape: 1])}, {2.9, change(:tom, send: [tape: 0])}], 8)"
    buses = "buses: [tape: [echo: [phase: 0.25, decay: 0.5]]]"
    dry = render(ctx, "song(tempo: 120, #{buses}, music: #{hits})")
    thrown = render(ctx, "song(tempo: 120, #{buses}, music: together([#{hits}, #{throw}]))")
    echoes = Enum.zip_with(thrown, dry, &(&1 - &2))

    # Hits fall on seconds 0, 1, 2 and 3; only the one at 1 second is sent, and its echoes follow
    # it.
    assert peak(between(echoes, 0, 1)) < 1.0e-6
    assert peak(between(echoes, 1.1, 1.9)) > 0.01
    assert peak(between(echoes, 3, 4)) < peak(between(echoes, 1.1, 1.9)) / 30
    assert peak(dry) > 0.05
  end

  @tag :engine
  test "a send's level glides over send_slide beats while the dry sound plays on", ctx do
    held = "part(:pad, note(:a3, 8, amp: 0.3), synth: :tri, send: [wet: 1])"
    fade = "at([{2, change(:pad, send: [wet: 0], send_slide: 2)}], 8)"
    buses = "buses: [wet: [level: []]]"
    dry = render(ctx, "song(tempo: 120, music: #{String.replace(held, ", send: [wet: 1]", "")})")
    steady = render(ctx, "song(tempo: 120, #{buses}, music: #{held})")
    faded = render(ctx, "song(tempo: 120, #{buses}, music: together([#{held}, #{fade}]))")
    level = fn samples, at -> peak(between(samples, at, at + 0.05)) end
    assert_in_delta level.(steady, 0.5) / level.(dry, 0.5), 2, 0.01
    assert_in_delta level.(faded, 0.5) / level.(dry, 0.5), 2, 0.01

    # Two beats at 120 are a second: halfway down at 1.5 seconds, out by 2, and the dry sound as
    # it was.
    assert_in_delta level.(faded, 1.5) / level.(dry, 1.5), 1.5, 0.1
    assert_in_delta level.(faded, 2.2) / level.(dry, 2.2), 1, 0.01
    assert_in_delta level.(faded, 3.5) / level.(dry, 3.5), 1, 0.01
  end

  @tag :engine
  test "a bus sends into another bus, and a change reaches an effect of a bus", ctx do
    tick = "part(:x, seq([note(:a2, 0.25), rest(3.75)]), synth: :tri, send: [first: 1])"
    one = "buses: [first: [level: []]]"
    two = "buses: [first: [fx: [level: []], send: [second: 1]], second: [level: []]]"

    dry =
      render(ctx, "song(tempo: 120, music: #{String.replace(tick, ", send: [first: 1]", "")})")

    once = render(ctx, "song(tempo: 120, #{one}, music: #{tick})")
    twice = render(ctx, "song(tempo: 120, #{two}, music: #{tick})")
    assert_in_delta peak(once) / peak(dry), 2, 0.001
    assert_in_delta peak(twice) / peak(dry), 3, 0.001

    off = "at([{0, change({:first, :level}, amp: 0)}], 4)"
    quiet = render(ctx, "song(tempo: 120, #{one}, music: together([#{tick}, #{off}]))")
    assert_in_delta peak(from(quiet, 0.05)) / peak(from(dry, 0.05)), 1, 0.001
  end

  test "an effect of a bus has a mix of 1 unless it gives one", ctx do
    note = "part(:x, note(:a2, 1), synth: :saw, send: [room: 0.2, tape: 1])"

    buses =
      "buses: [room: [reverb: [decay_seconds: 2.3]], tape: [fx: [echo: [mix: 0.4], lpf: []], send: [room: 0.3]]]"

    assert {:ok, song} = load(ctx, "song(#{buses}, music: #{note})")

    assert song.buses == [
             %Mx.Song.Bus{name: :room, fx: [reverb: [mix: 1, decay_seconds: 2.3]], send: []},
             %Mx.Song.Bus{name: :tape, fx: [echo: [mix: 0.4], lpf: [mix: 1]], send: [room: 0.3]}
           ]

    assert [%{name: :x, send: [room: 0.2, tape: 1]}] = song.loops
  end

  test "buses that send into each other are refused, naming them", ctx do
    note = "part(:x, note(:a2, 1), synth: :saw)"
    path = Path.join(ctx.tmp_dir, "song.exs")

    looped =
      "buses: [tape: [fx: [echo: []], send: [room: 1]], room: [fx: [reverb: []], send: [tape: 0.2]]]"

    assert load(ctx, "song(#{looped}, music: #{note})") ==
             {:error, "#{path}:2: bus tape sends into itself, through room"}

    assert load(ctx, "song(buses: [room: [fx: [reverb: []], send: [room: 1]]], music: #{note})") ==
             {:error, "#{path}:2: bus room sends into itself"}

    assert load(ctx, "song(buses: [room: [fx: [reverb: []], send: [hall: 1]]], music: #{note})") ==
             {:error,
              "#{path}:2: bus room sends to hall, which the song does not declare; declare it with bus :hall, fx: ..."}

    assert load(ctx, "song(buses: [room: [revereb: []]], music: #{note})") ==
             {:error, "#{path}:2: bus room: mx has no effect revereb"}

    assert load(ctx, "song(buses: [song: [reverb: []]], music: #{note})") ==
             {:error,
              "#{path}:2: a bus cannot be named song: the name is taken by the song's own chain"}
  end

  test "a send to a bus the song does not declare is refused, naming the part and the bus", ctx do
    path = Path.join(ctx.tmp_dir, "song.exs")
    sent = "part(:snare, note(:a2, 1), synth: :saw, send: [hall: 0.3])"

    assert load(ctx, "song(buses: [room: [reverb: []]], music: #{sent})") ==
             {:error,
              "#{path}:2: part snare sends to hall, which the song does not declare; declare it with bus :hall, fx: ..."}

    assert load(ctx, "song(music: part(:snare, note(:a2, 1), synth: :saw, send: [room: -1]))") ==
             {:error,
              "#{path}:2: part snare: send: takes a level of 0 or more for each bus, such as send: [room: 0.3], not [room: -1]"}

    note = "part(:snare, note(:a2, 1), synth: :saw)"
    changed = "together([#{note}, change(:snare, send: [hall: 1])])"

    assert load(ctx, "song(buses: [room: [reverb: []]], music: #{changed})") ==
             {:error,
              "#{path}:2: change of part snare sends to hall, which the song does not declare; declare it with bus :hall, fx: ..."}

    reached = "together([#{note}, change({:room, :echo}, mix: 1)])"

    assert load(ctx, "song(buses: [room: [reverb: []]], music: #{reached})") ==
             {:error, "#{path}:2: change names effect echo, which bus room does not have"}

    assert {:ok, song} =
             load(
               ctx,
               "song(buses: [room: [reverb: []]], music: together([#{note}, change(:snare, send: [room: 1])]))"
             )

    assert [%{name: :snare, send: [room: 0]}] = song.loops
  end

  test "live audio takes send: as a part does", ctx do
    note = "part(:x, note(:a2, 1), synth: :saw)"

    live = fn send ->
      "song(buses: [room: [reverb: []]], live_audio: [mic: [amp: 0.8, send: #{send}]], music: #{note})"
    end

    assert {:ok, %{live: [%{name: :mic, send: [room: 0.3], opts: [amp: 0.8]}]}} =
             load(ctx, live.("[room: 0.3]"))

    assert load(ctx, live.("[hall: 0.3]")) ==
             {:error,
              "live_audio mic sends to hall, which the song does not declare; declare it with bus :hall, fx: ..."}
  end

  test "a part and a bus of one name are refused", ctx do
    path = Path.join(ctx.tmp_dir, "song.exs")
    note = "part(:room, note(:a2, 1), synth: :saw)"

    assert load(ctx, "song(buses: [room: [reverb: []]], music: #{note})") ==
             {:error,
              "#{path}:2: room is the name of a part and of a bus, and a change could not tell them apart"}
  end

  @tag :engine
  test "a render's ring-out lasts until a bus's reverb has faded", ctx do
    sent = "part(:x, note(:a2, 1), synth: :saw, send: [room: 1])"

    song =
      "song(tempo: 120, buses: [tape: [echo: []], room: [reverb: [decay_seconds: 6]]], music: #{sent})"

    {:ok, loaded} = load(ctx, song)
    assert {:ok, %{seconds: 6.0, part: :room, effect: :reverb}} = Mx.Render.ring_out(loaded)

    short = render(ctx, song, ring_out: false)
    long = render(ctx, song, ring_out: true)
    # Without the ring the render ends as the note fades, half a second after the music.
    assert_in_delta (length(long) - length(short)) / @rate, 6.5, 0.1
    assert peak(from(long, length(short) / @rate + 1)) > 1.0e-4

    {:ok, dry} =
      load(
        ctx,
        "song(tempo: 120, buses: [room: [reverb: []]], music: part(:x, note(:a2, 1), synth: :saw))"
      )

    assert {:ok, nil} = Mx.Render.ring_out(dry)
  end

  @tag :engine
  test "a module song declares its buses beside its parts", ctx do
    path = Path.join(ctx.tmp_dir, "module.exs")
    out = Path.join(ctx.tmp_dir, "module.wav")

    File.write!(path, """
    defmodule Mx.BusesTest.Dub do
      use Mx.Song, tempo: 120

      bus :room, fx: [reverb: [decay_seconds: 1.2]]
      bus :tape, fx: [echo: [phase: 0.75]], send: [room: 0.3]

      part :tom, synth: :tri, send: [room: 0.2]

      def song, do: part(:tom, seq([note(:a2, 1), change(:tom, send: [tape: 1]), note(:a2, 1), rest(2)]))
    end
    """)

    assert {:ok, song} = Mx.Song.load(path)
    assert [%{name: :room, send: []}, %{name: :tape, send: [room: 0.3]}] = song.buses
    assert [%{name: :tom, send: [room: 0.2, tape: 0]}] = song.loops
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    assert Mx.Recording.level(out).peak > -40
  after
    :code.purge(Mx.BusesTest.Dub)
    :code.delete(Mx.BusesTest.Dub)
  end
end
