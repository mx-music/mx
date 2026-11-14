defmodule Mx.Examples.FluteTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/flute.exs"

  test "the solo plays only the flute" do
    assert Regex.scan(~r/^(\w+), /m, print(0), capture: :all_but_first) == [["flute"]]
    refute print(0) =~ "sample "
  end

  test "Syrinx opens on one breath from B flat 5 through the fermata, its later notes moving the held note" do
    assert print(0) =~ ~r/\nbeat 0 +play 82 vel: 0.5, sustain: 7.4, release: 0.3\n/
    assert print(0) =~ ~r/\nbeat 0.75 +control note: 81, note_slide: 0\n/
    assert print(0) =~ ~r/\nbeat 7.5 +play 82 vel: 0.5, sustain: 4.4, release: 0.3\n/
  end

  test "a note starting a slur is tongued, dipping the breath to a quarter and bringing it back" do
    assert print(0) =~ ~r/\nbeat 0.975 +control vel: 0.125, vel_slide: 0.02\n/
    assert print(0) =~ ~r/\nbeat 1 +control note: 80, note_slide: 0, vel: 0.5, vel_slide: 0.025\n/
  end

  test "the last breath slows to the end and holds the low D flat" do
    assert print(0) =~ ~r/\nbeat 101.31 +play 71 vel: 0.35, sustain: 14.7, release: 0.3\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/flute.exs"
    assert File.read!("LICENSE-designs.md") =~ "The flute is measured"
  end

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the solo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "solo.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@song, "--record", out])
    after
      Process.group_leader(self(), leader)
    end

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([@song, "--pass", pass]) end)
  end

  # An input device that answers the first line asked for after a delay, as a person pressing
  # Enter would.
  defp enter_after(ms) do
    receive do
      {:io_request, from, ref, {:get_line, _, _}} ->
        Process.sleep(ms)
        send(from, {:io_reply, ref, "\n"})
        enter_after(ms)

      {:io_request, from, ref, _request} ->
        send(from, {:io_reply, ref, :ok})
        enter_after(ms)
    end
  end
end
