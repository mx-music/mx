defmodule Mx.Examples.ClarinetTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/clarinet.exs"

  test "the solo plays only the clarinet" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["clarinet"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the melody starts softly low in its range and reaches down to its low D" do
    assert print(0) =~ ~r/\nbeat 0 +play 55 vel: 0.4, sustain: 1.4, release: 0.15\n/
    assert print(0) =~ ~r/\nbeat 11 +play 50 vel: 0.4, sustain: 0.9, release: 0.15\n/
  end

  test "the arpeggios climb in sixteenths, the second time an octave up" do
    assert print(1) =~ ~r/\nbeat 1.75 +play 82 vel: 0.6, sustain: 0.15, release: 0.05\n/
    assert print(2) =~ ~r/\nbeat 1.75 +play 94 vel: 0.6, sustain: 0.15, release: 0.05\n/
  end

  test "the melody comes back higher, and the last phrase climbs loud to G6" do
    assert print(3) =~ ~r/\nbeat 0 +play 74 vel: 0.65, sustain: 1.4, release: 0.2\n/
    assert print(4) =~ ~r/\nbeat 3 +play 91 vel: 0.85, sustain: 5.9, release: 0.4\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/clarinet.exs"
    assert File.read!("LICENSE-designs.md") =~ "The clarinet is measured"
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
