defmodule Mx.Examples.GlockenspielTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/glockenspiel.exs"

  test "the solo plays only the glockenspiel" do
    for pass <- 0..3 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["glockenspiel"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the melody stays high and each note is damped as the next one comes" do
    melody = print(0)
    assert melody =~ ~r/\nbeat 0 +play 88 vel: 0.6, release: 0.1, sustain: 0.9\nbeat 1 +play 91 /
    notes = Regex.scan(~r/play (\d+) /, melody, capture: :all_but_first)
    assert Enum.all?(notes, fn [note] -> String.to_integer(note) >= 84 end)
  end

  test "the chord's notes are left to ring" do
    assert print(2) =~ ~r/\nbeat 0 +play 72 vel: 0.7, release: 0.3, sustain: 1000\n/
  end

  test "the ending climbs to E8, the top bar" do
    assert print(3) =~ ~r/\nbeat 3.5 +play 112 vel: 0.65, release: 0.3, sustain: 1000\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/glockenspiel.exs"
    assert File.read!("LICENSE-designs.md") =~ "The glockenspiel is measured"
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
