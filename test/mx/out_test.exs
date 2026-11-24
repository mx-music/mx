defmodule Mx.OutTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mx.{OSC, Out}

  # It opens MIDI ports, so it needs ALSA's sequencer on Linux.
  @moduletag :midi

  setup do
    out = start_supervised!({Out, name: nil})
    %{out: out}
  end

  test "sends an OSC message at its time", %{out: out} do
    {receiver, port} = udp_receiver()
    at = now() + 50_000

    Out.schedule(out, at, {:osc, {"127.0.0.1", port}, OSC.message("/hello", [1, "a"])})

    assert_receive {:udp, ^receiver, _, _, packet}
    arrived = now()
    assert OSC.decode(packet) == {"/hello", [1, "a"]}
    assert arrived >= at
    assert arrived - at < 2000
  end

  test "sends MIDI to the named port at its time, and to no other port", %{out: out} do
    other = listen("mx out test other")
    name = listen("mx out test named")
    at = now() + 50_000

    Out.schedule(out, at, {:midi, name, <<0x91, 60, 100>>})

    assert_receive {:midi, ^name, <<0x91, 60, 100>>, arrived}
    assert arrived >= at
    assert arrived - at < 2000
    refute_receive {:midi, ^other, _, _}
  end

  test "MIDI with no port goes to every connected port", %{out: out} do
    first = listen("mx out test first")
    second = listen("mx out test second")

    Out.schedule(out, now() + 20_000, {:midi, nil, <<0x90, 62, 90>>})

    assert_receive {:midi, ^first, <<0x90, 62, 90>>, _}
    assert_receive {:midi, ^second, <<0x90, 62, 90>>, _}
  end

  test "a port that is not connected prints one warning naming it", %{out: out} do
    output =
      capture_io(:stderr, fn ->
        for step <- 1..3,
            do: Out.schedule(out, now() + step * 10_000, {:midi, "mx nope", <<0x90, 60, 1>>})

        Process.sleep(100)
      end)

    assert output == "MIDI port mx nope is not connected, so its messages are dropped.\n"
  end

  test "an OSC destination that cannot be reached prints one warning naming it", %{out: out} do
    output =
      capture_io(:stderr, fn ->
        for step <- 1..3 do
          Out.schedule(
            out,
            now() + step * 10_000,
            {:osc, {"no-such-host.invalid", 9000}, OSC.message("/x", [])}
          )
        end

        Process.sleep(100)
      end)

    assert output =~ ~r/^cannot send OSC to no-such-host.invalid:9000: .+\n$/
  end

  test "stopping sends note off for every MIDI note still sounding", %{out: out} do
    name = listen("mx out test stop")

    Out.schedule(out, now() + 10_000, {:midi, name, <<0x92, 64, 100>>})
    Out.schedule(out, now() + 15_000, {:midi, name, <<0x92, 65, 100>>})
    Out.schedule(out, now() + 20_000, {:midi, name, <<0x82, 65, 0>>})
    Out.schedule(out, now() + 5_000_000, {:midi, name, <<0x82, 64, 0>>})
    assert_receive {:midi, ^name, <<0x82, 65, 0>>, _}

    stop_supervised!(Out)

    assert_receive {:midi, ^name, <<0x82, 64, 0>>, _}
    refute_receive {:midi, ^name, <<0x82, _, _>>, _}
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 120_000
  test "over a minute of sixteenth notes while other loops play, messages arrive within 2 ms, and none more than 10 ms late",
       %{out: out, tmp_dir: dir} do
    name = listen("mx out test timing")
    {receiver, port} = udp_receiver()
    path = Path.join(dir, "song.exs")

    File.write!(path, """
    import Mx

    song(tempo: 120, osc_to: {"127.0.0.1", #{port}}, music: together([
      part(:out, loop(4, fn _, _ ->
        at(Enum.flat_map(0..15, fn step -> [{step * 0.25, midi(60 + rem(step, 12), 0.125)}, {step * 0.25, osc("/step", [step])}] end), 4)
      end), midi: "#{name}"),
      part(:hats, loop(0.25, fn _, _ -> seq([note(60, 0, amp: 0.2), rest(0.25)]) end)),
      part(:busy, loop(0.125, fn _, _ ->
        Enum.reduce(1..20_000, 0, &(&1 + &2))
        seq([note(72, 0), rest(0.125)])
      end))
    ]))
    """)

    {:ok, song} = Mx.Song.load(path)
    start_us = now() + 500_000

    {:ok, band} =
      Mx.Band.start_link(
        song: song,
        play: fn _, _ -> :ok end,
        out: &Out.schedule(out, &1, &2),
        start_us: start_us
      )

    arrivals = collect_arrivals(receiver, name, start_us + 60_000_000, [])
    GenServer.stop(band)

    offsets =
      for at <- arrivals do
        step = round((at - start_us) / 125_000)
        at - (start_us + step * 125_000)
      end

    sorted = Enum.sort(offsets)
    percentile_99 = Enum.at(sorted, floor(0.99 * length(sorted)))

    assert length(offsets) >= 2 * 470
    assert hd(sorted) >= 0
    assert percentile_99 < 2000, inspect(Enum.take(sorted, -10))
    assert List.last(sorted) < 10_000
  end

  # The arrival times of every OSC message and MIDI note on until the deadline.
  defp collect_arrivals(receiver, name, deadline, arrivals) do
    receive do
      {:udp, ^receiver, _, _, _packet} ->
        collect_arrivals(receiver, name, deadline, [now() | arrivals])

      {:midi, ^name, <<0x90, _, _>>, at} ->
        collect_arrivals(receiver, name, deadline, [at | arrivals])

      {:midi, ^name, _, _} ->
        collect_arrivals(receiver, name, deadline, arrivals)
    after
      max(0, div(deadline - now(), 1000)) -> arrivals
    end
  end

  defp listen(name) do
    test = self()
    port = Midiex.create_virtual_input(name)
    {:ok, listener} = Midiex.Listener.start_link(port: port)

    Midiex.Listener.add_handler(listener, fn msg -> send(test, {:midi, name, msg.data, now()}) end)

    wait_for_output(name, 50)
    name
  end

  defp wait_for_output(name, 0), do: flunk("MIDI port #{name} did not appear")

  defp wait_for_output(name, tries) do
    if Midiex.ports(name, :output) == [] do
      Process.sleep(20)
      wait_for_output(name, tries - 1)
    end
  end

  defp udp_receiver do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
    {:ok, port} = :inet.port(socket)
    {socket, port}
  end

  defp now, do: System.os_time(:microsecond)
end
