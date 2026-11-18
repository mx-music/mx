defmodule Mx.BeatTest do
  use ExUnit.Case, async: true, group: :stderr

  import ExUnit.CaptureIO

  alias Mx.{Band, Beat, Song}

  @moduletag :tmp_dir

  @loop "part(:a, loop(4, fn _, _ -> seq([note(60, 0), rest(4)]) end))"

  describe "the beat worked out from a message" do
    test "moves on at a held tempo, before and after the beat it gives" do
      message = %{beat: 16, tempo: 90, heard_us: 8_000_000}

      assert Beat.at(message, 8_000_000) == 16
      assert_in_delta Beat.at(message, 10_000_000), 19, 1.0e-9
      assert_in_delta Beat.at(message, 7_000_000), 14.5, 1.0e-9
      assert Beat.heard_at(message, 19) == 10_000_000
    end

    test "follows a tempo that moves, and the tempo it ends at from then on" do
      message = %{beat: 0, tempo: {:ramp, 120, 60, 4}, heard_us: 1_000_000}
      # Four beats from 120 to 60 last 4 * ln(2) seconds, and the first two last 4 * ln(4 / 3).
      two_in = 1_000_000 + round(4 * :math.log(4 / 3) * 1_000_000)
      ended = 1_000_000 + round(4 * :math.log(2) * 1_000_000)

      assert_in_delta Beat.at(message, two_in), 2, 1.0e-5
      assert_in_delta Beat.at(message, ended), 4, 1.0e-5
      assert_in_delta Beat.at(message, ended + 3_000_000), 7, 1.0e-5
      assert_in_delta Beat.at(message, 500_000), -1, 1.0e-9
      assert Beat.heard_at(message, 2) == two_in
      assert Beat.heard_at(message, 7) == ended + 3_000_000
    end
  end

  describe "the messages of a timeline" do
    test "give one for a ramp and none for the tempo it ends at" do
      timeline = Mx.Tempo.new(120) |> Mx.Tempo.put(8, 60, 4) |> Mx.Tempo.put(20, 90, 0)

      assert [
               %{beat: 0, tempo: 120, heard_us: 7},
               %{beat: 8, tempo: {:ramp, 120, 60, 4}, heard_us: 4_000_007},
               %{beat: 20, tempo: 90, heard_us: twenty}
             ] = Beat.messages(timeline, 7, 0)

      assert twenty == Mx.Tempo.time_at(timeline, 20) + 7
    end

    test "start from the one that holds now" do
      timeline = Mx.Tempo.new(120) |> Mx.Tempo.put(8, 60, 0) |> Mx.Tempo.put(20, 90, 0)

      assert [%{beat: 8}, %{beat: 20}] = Beat.messages(timeline, 0, 4_000_000)
      assert [%{beat: 20}] = Beat.messages(timeline, 0, 60_000_000)
    end
  end

  test "a song at tempo 120 sends one message at its start, and none in the next 10 seconds",
       ctx do
    capture_io(:stderr, fn ->
      {band, start_us} = start(ctx, song(120))
      :ok = Band.follow(band)

      assert_receive {:mx_beat, %{beat: 0, tempo: 120, heard_us: ^start_us} = message}
      refute_receive {:mx_beat, _}, 10_000

      assert_in_delta Beat.at(message, start_us + 5_000_000), 10, 0.01
      assert_in_delta Band.beat_at(Band.timeline(band), start_us + 5_000_000), 10, 0.01
    end)
  end

  test "a beat is heard the output's delay after its time, and is sent again when the delay moves",
       ctx do
    capture_io(:stderr, fn ->
      test = self()

      delay = fn band ->
        send(test, {:band, band})
        12_000
      end

      {band, start_us} = start(ctx, song(120), delay: delay, follow: [self()])

      assert_receive {:band, ^band}
      assert_receive {:mx_beat, %{beat: 0, tempo: 120, heard_us: heard_us}}
      assert heard_us == start_us + 12_000

      send(band, {:mx_delay, 15_500})
      assert_receive {:mx_beat, %{beat: 0, tempo: 120, heard_us: heard_us}}
      assert heard_us == start_us + 15_500
      refute_receive {:mx_beat, _}, 100
    end)
  end

  test "a saved tempo of 90 that starts at beat 16 sends that beat, the tempo and when it is heard",
       ctx do
    capture_io(:stderr, fn ->
      # Beat 15.2 is 20 ms ahead when the song is saved, so the new tempo starts at beat 16.
      start_us = System.os_time(:microsecond) + 20_000 - 7_600_000
      {band, ^start_us} = start(ctx, song(120), start_us: start_us)
      :ok = Band.follow(band)
      assert_receive {:mx_beat, %{beat: 0, tempo: 120}}

      Band.switch(band, load(ctx, song(90)))

      assert_receive {:mx_beat, %{beat: 16, tempo: 90, heard_us: heard_us}}
      assert heard_us == start_us + 8_000_000
      refute_receive {:mx_beat, _}, 100
    end)
  end

  test "a saved version with the same tempo sends nothing, and the beat worked out moves on",
       ctx do
    capture_io(:stderr, fn ->
      {band, start_us} = start(ctx, song(120))
      :ok = Band.follow(band)
      assert_receive {:mx_beat, %{} = message}

      Band.switch(band, load(ctx, song(120)))

      refute_receive {:mx_beat, _}, 300
      now = System.os_time(:microsecond)
      assert_in_delta Beat.at(message, now), (now - start_us) / 500_000, 1.0e-9
      assert_in_delta Beat.at(message, now), Band.beat_at(Band.timeline(band), now), 1.0e-9
    end)
  end

  test "a tempo the music moves from 120 to 60 over 4 beats sends one message for the move",
       ctx do
    capture_io(:stderr, fn ->
      music = "part(:a, seq([tempo(60, over: 4), repeat(seq([note(60, 0), rest(1)]), 12)]))"
      song = load(ctx, "import Mx\nsong(tempo: 120, music: #{music})\n")
      {_band, start_us} = start(ctx, song, follow: [self()])

      assert_receive {:mx_beat, %{beat: 0, tempo: 120, heard_us: ^start_us}}
      assert_receive {:mx_beat, %{beat: 0, tempo: {:ramp, 120, 60, 4}} = message}
      assert message.heard_us == start_us
      refute_receive {:mx_beat, _}, 100

      two_in = start_us + round(4 * :math.log(4 / 3) * 1_000_000)
      assert_in_delta Beat.at(message, two_in), 2, 0.01
    end)
  end

  @tag :capture_log
  test "stopping the song sends a message that says it stopped", ctx do
    capture_io(:stderr, fn ->
      {band, _start_us} = start(ctx, song(120))
      :ok = Band.follow(band)
      assert_receive {:mx_beat, %{beat: 0}}

      GenServer.stop(band)

      assert_receive {:mx_beat, :stopped}
    end)
  end

  test "a follower that is gone is sent nothing more", ctx do
    capture_io(:stderr, fn ->
      {band, _start_us} = start(ctx, song(120))
      follower = spawn(fn -> Band.follow(band) end)
      ref = Process.monitor(follower)
      assert_receive {:DOWN, ^ref, :process, ^follower, _}

      Band.switch(band, load(ctx, song(90)))

      assert %{followers: []} = :sys.get_state(band)
    end)
  end

  defp song(tempo), do: "import Mx\nsong(tempo: #{tempo}, music: #{@loop})\n"

  defp start(ctx, song, opts \\ [])

  defp start(ctx, song, opts) when is_binary(song), do: start(ctx, load(ctx, song), opts)

  defp start(_ctx, %Song{} = song, opts) do
    start_us = System.os_time(:microsecond) + 20_000
    play = fn _at_us, _events -> :ok end
    opts = Keyword.merge([song: song, play: play, ahead_ms: 20, start_us: start_us], opts)
    {:ok, band} = Band.start_link(opts)
    {band, opts[:start_us]}
  end

  defp load(%{tmp_dir: dir}, content) do
    path = Path.join(dir, "song_#{System.unique_integer([:positive])}.exs")
    File.write!(path, content)
    {:ok, song} = Song.load(path)
    song
  end
end
