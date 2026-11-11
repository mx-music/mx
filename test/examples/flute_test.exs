defmodule Mx.Examples.FluteTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/flute/solo.exs"

  test "the solo plays only the flute" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["flute"]]
    end

    refute print(0) =~ "sample "
  end

  test "the lyrical melody holds its notes with vibrato" do
    assert print(0) =~
             ~r/\nbeat 4 +play 79 vel: 0.6, sustain: 1.85, release: 0.2, vibrato: 0.25\n/
  end

  test "the runs climb in sixteenths without vibrato, the second time from A4" do
    assert print(1) =~
             ~r/\nbeat 0.25 +play 64 vel: 0.6, sustain: 0.15, release: 0.05, vibrato: 0\n/

    assert print(2) =~ ~r/\nbeat 0 +play 69 vel: 0.75, sustain: 0.15, release: 0.05, vibrato: 0\n/
  end

  test "the melody comes back softly down to the low B, and the last phrase climbs loud to A6" do
    assert print(3) =~
             ~r/\nbeat 10 +play 59 vel: 0.35, sustain: 0.85, release: 0.2, vibrato: 0.25\n/

    assert print(4) =~
             ~r/\nbeat 3 +play 93 vel: 0.9, sustain: 5.85, release: 0.4, vibrato: 0.25\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/flute"
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
      Mix.Tasks.Mx.Play.run([@song, "--record", out, "--port", "57190"])
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

  # An input device that answers the first line asked for after a delay, as a person pressing Enter would.
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
