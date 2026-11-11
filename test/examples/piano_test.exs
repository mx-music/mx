defmodule Mx.Examples.PianoTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/piano/solo.exs"

  test "the solo plays only the piano" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["piano"]]
    end

    refute print(0) =~ "sample "
  end

  test "the sweep runs from A0 to C8 and back" do
    sweep = print(0)
    assert sweep =~ ~r/\nbeat 0 +play 21 /
    assert sweep =~ ~r/play 108 vel: 0.6/
    assert sweep =~ ~r/play 21 vel: 0.6, sustain: 0.5\n\z/
  end

  test "the chords are played softly and then hard, and the runs go over a bass" do
    assert print(1) =~ ~r/\nbeat 0 +play 48 vel: 0.2, sustain: 1.8\n/
    assert print(2) =~ ~r/\nbeat 0 +play 60 vel: 0.75, sustain: 1.8\n/

    assert print(3) =~
             ~r/\nbeat 0 +play 36 vel: 0.7, sustain: 1.9\nbeat 0 +play 60 vel: 0.55, sustain: 0.3\nbeat 0.25 +play 67 /
  end

  test "the end strikes the lowest and highest notes at the hardest and the softest" do
    extremes = print(5)

    assert extremes =~
             ~r/\nbeat 0 +play 21 vel: 1, sustain: 3\nbeat 1 +play 108 vel: 1, sustain: 2.5\n/

    assert extremes =~
             ~r/\nbeat 3 +play 108 vel: 0.15, sustain: 2\nbeat 4 +play 21 vel: 0.15, sustain: 3\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/piano"
    assert File.read!("LICENSE-designs.md") =~ "Steinway B"
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
