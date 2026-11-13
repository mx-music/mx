defmodule Mx.Examples.BassoonTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/bassoon.exs"

  test "the solo plays only the bassoon" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["bassoon"]]
    end

    refute print(0) =~ "sample "
  end

  test "the melody sings in its tenor register with a little vibrato" do
    assert print(0) =~ ~r/\nbeat 2 +play 65 vel: 0.6, sustain: 1.4, release: 0.15, vibrato: 0.1\n/
  end

  test "the bass line walks from its low B flat" do
    assert print(1) =~ ~r/\nbeat 0 +play 34 vel: 0.7, sustain: 0.8, release: 0.1\n/
  end

  test "the detached tune is short, the second time an octave down" do
    assert print(2) =~ ~r/\nbeat 0 +play 65 vel: 0.7, sustain: 0.08, release: 0.04\n/
    assert print(3) =~ ~r/\nbeat 0 +play 53 vel: 0.7, sustain: 0.08, release: 0.04\n/
  end

  test "the solo closes on its low B flat, held" do
    assert print(4) =~ ~r/\nbeat 10 +play 34 vel: 0.75, sustain: 5.5, release: 0.6\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/bassoon.exs"
    assert File.read!("LICENSE-designs.md") =~ "The bassoon is measured"
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
