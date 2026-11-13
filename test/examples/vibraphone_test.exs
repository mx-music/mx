defmodule Mx.Examples.VibraphoneTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/vibraphone.exs"

  test "the solo plays only the vibraphone" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["vibraphone"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the chords ring with the pedal, and then again with the motor turning" do
    assert print(0) =~ ~r/\nbeat 0 +play 53 vel: 0.5, motor: 0, release: 0.1, sustain: 1.9\n/
    assert print(1) =~ ~r/\nbeat 0 +play 53 vel: 0.5, motor: 2, release: 0.1, sustain: 1.9\n/
  end

  test "the line is of short damped notes over a held note" do
    assert print(2) =~
             ~r/\nbeat 0 +play 53 vel: 0.4, motor: 0, release: 0.1, sustain: 1.9\nbeat 0 +play 69 vel: 0.6, motor: 0, release: 0.05, sustain: 0.2\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/vibraphone.exs"
    assert File.read!("LICENSE-designs.md") =~ "The vibraphone is measured"
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
