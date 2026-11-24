defmodule Mx.InputsTest do
  use ExUnit.Case

  alias Mx.{Inputs, OSC}

  # It opens MIDI ports, so it needs ALSA's sequencer on Linux.
  @moduletag :midi

  @osc_port 57_291

  setup do
    id = System.unique_integer([:positive])
    name = "mx inputs test #{id}"
    device = Midiex.create_virtual_output(name)
    wait_for_input(name, 50)
    inputs = start_supervised!({Inputs, name: nil, osc_port: @osc_port})
    Inputs.subscribe(inputs, self())
    warm_up(device, 50)
    %{inputs: inputs, device: device}
  end

  test "keeps the latest value of each MIDI controller and note from connected devices", ctx do
    Midiex.send_msg(ctx.device, <<0xB0, 74, 64>>)
    Midiex.send_msg(ctx.device, <<0x93, 60, 100>>)
    Midiex.send_msg(ctx.device, <<0x93, 62, 90>>)
    Midiex.send_msg(ctx.device, <<0x83, 62, 0>>)

    assert_receive {:input, {:midi_cc, %{number: 74, value: 64}}}
    assert_receive {:input, {:midi_note, %{note: 60, velocity: 100}}}
    assert_receive {:input, {:midi_note, %{note: 62, velocity: 90}}}
    refute_receive {:input, {:midi_note, %{note: 62, velocity: 0}}}

    assert %{{:cc, 74} => 64, {:note, 60} => 100, {:note, 62} => 0} = Inputs.snapshot(ctx.inputs)

    Midiex.send_msg(ctx.device, <<0xB0, 74, 10>>)
    assert_receive {:input, {:midi_cc, %{number: 74, value: 10}}}
    assert Inputs.snapshot(ctx.inputs)[{:cc, 74}] == 10
  end

  test "keeps the latest arguments of each OSC address on the song's port", ctx do
    {:ok, socket} = :gen_udp.open(0, [:binary])
    :gen_udp.send(socket, ~c"127.0.0.1", @osc_port, OSC.message("/trigger", [1, "a"]))

    assert_receive {:input, {:osc, %{address: "/trigger", args: [1, "a"]}}}
    assert Inputs.snapshot(ctx.inputs)[{:osc, "/trigger"}] == [1, "a"]
    assert Inputs.snapshot_at(ctx.inputs, 0, now())[{:osc, "/trigger"}] == [1, "a"]
  end

  test "listens on another OSC port when the song names one", ctx do
    Inputs.listen(ctx.inputs, @osc_port + 1)
    {:ok, socket} = :gen_udp.open(0, [:binary])
    Process.sleep(50)
    :gen_udp.send(socket, ~c"127.0.0.1", @osc_port + 1, OSC.message("/moved", [2]))

    assert_receive {:input, {:osc, %{address: "/moved", args: [2]}}}
  end

  test "a pass reads each shared value as the last set step before its first beat left it", ctx do
    Inputs.put(ctx.inputs, :root, 41, 1, now())
    Inputs.put(ctx.inputs, :root, 40, 0, now())

    assert Inputs.snapshot_at(ctx.inputs, 0, now())[{:value, :root}] == nil
    assert Inputs.snapshot_at(ctx.inputs, 1, now())[{:value, :root}] == 40
    assert Inputs.snapshot_at(ctx.inputs, 1.5, now())[{:value, :root}] == 41
    assert Inputs.snapshot_at(ctx.inputs, 2, now())[{:value, :other}] == nil
  end

  test "shares a value from the time its beat plays", ctx do
    Inputs.put(ctx.inputs, :root, 40, 0, now() + 100_000)

    assert Inputs.snapshot(ctx.inputs)[{:value, :root}] == nil
    Process.sleep(150)
    assert Inputs.snapshot(ctx.inputs)[{:value, :root}] == 40
  end

  test "a pass's snapshot waits until every followed loop has worked out up to its beat", ctx do
    setter = spawn(fn -> Process.sleep(:infinity) end)
    :ok = Inputs.worked_out(ctx.inputs, setter, 0)

    reader = Task.async(fn -> Inputs.snapshot_at(ctx.inputs, 2, now() + 1_000_000) end)
    refute Task.yield(reader, 50)

    Inputs.put(ctx.inputs, :root, 40, 1, now())
    :ok = Inputs.worked_out(ctx.inputs, setter, 2)
    assert Task.await(reader, 100)[{:value, :root}] == 40
  end

  test "a followed loop's pass never waits for itself, and its own set steps reach its next pass",
       ctx do
    :ok = Inputs.worked_out(ctx.inputs, self(), 0)
    assert Inputs.snapshot_at(ctx.inputs, 0, now() + 1_000_000)[{:value, :root}] == nil

    Inputs.put(ctx.inputs, :root, 40, 0, now())
    :ok = Inputs.worked_out(ctx.inputs, self(), 1)
    assert Inputs.snapshot_at(ctx.inputs, 1, now() + 1_000_000)[{:value, :root}] == 40
  end

  test "a snapshot stops waiting at the time given, or once the loop it waits for is no longer followed",
       ctx do
    stuck = spawn(fn -> Process.sleep(:infinity) end)
    :ok = Inputs.worked_out(ctx.inputs, stuck, 0)

    started = now()
    assert %{} = Inputs.snapshot_at(ctx.inputs, 1, started + 100_000)
    assert (now() - started) in 90_000..200_000

    reader = Task.async(fn -> Inputs.snapshot_at(ctx.inputs, 1, now() + 1_000_000) end)
    refute Task.yield(reader, 50)
    :ok = Inputs.worked_out(ctx.inputs, stuck, nil)
    assert Task.await(reader, 100)

    :ok = Inputs.worked_out(ctx.inputs, stuck, 0)
    reader = Task.async(fn -> Inputs.snapshot_at(ctx.inputs, 1, now() + 1_000_000) end)
    refute Task.yield(reader, 50)
    Process.exit(stuck, :kill)
    assert Task.await(reader, 100)
  end

  @tag :tmp_dir
  test "a loop triggered by MIDI note on plays its pass within 20 ms of the note arriving", ctx do
    path = Path.join(ctx.tmp_dir, "keys.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:keys, loop(fn trigger, _ -> seq([note(trigger.note, 0), rest(1)]) end, on: :midi_note)))\n"
    )

    {:ok, song} = Mx.Song.load(path)
    test = self()

    {:ok, _band} =
      Mx.Band.start_link(
        song: song,
        play: fn at, events -> send(test, {:played, System.os_time(:microsecond), at, events}) end,
        subscribe: &Inputs.subscribe(ctx.inputs, &1)
      )

    Process.sleep(100)
    pressed = System.os_time(:microsecond)
    Midiex.send_msg(ctx.device, <<0x90, 67, 100>>)

    assert_receive {:played, sent, at, [{:note, _, _, 67, _, _}]}

    assert sent - pressed < 20_000
    assert at - pressed < 20_000
  end

  # A new virtual port can take a moment to deliver, so this sends controller 1 until one arrives.
  defp warm_up(_device, 0), do: flunk("the virtual MIDI port delivered nothing")

  defp warm_up(device, tries) do
    Midiex.send_msg(device, <<0xBF, 1, 0>>)

    receive do
      {:input, {:midi_cc, %{number: 1}}} -> flush_inputs()
    after
      50 -> warm_up(device, tries - 1)
    end
  end

  defp flush_inputs do
    receive do
      {:input, _} -> flush_inputs()
    after
      50 -> :ok
    end
  end

  defp wait_for_input(_name, 0), do: flunk("the virtual MIDI port did not appear")

  defp wait_for_input(name, tries) do
    if Enum.find(Midiex.ports(:input), &(&1.name == name)) == nil do
      Process.sleep(20)
      wait_for_input(name, tries - 1)
    end
  end

  defp now, do: System.os_time(:microsecond)
end
