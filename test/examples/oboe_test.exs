defmodule Mx.Examples.OboeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/oboe/solo.exs"

  test "the solo plays only the oboe" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["oboe"]]
    end

    refute print(0) =~ "sample "
  end

  test "the melody holds each note to just before the next" do
    assert print(0) =~ ~r/\nbeat 4 +play 70 vel: 0.55, sustain: 1.4, release: 0.15\n/
  end

  test "the dance is short and detached, the second time a fourth higher" do
    assert print(1) =~ ~r/\nbeat 0.75 +play 70 vel: 0.55, sustain: 0.08, release: 0.04\n/
    assert print(2) =~ ~r/\nbeat 0 +play 77 vel: 0.7, sustain: 0.08, release: 0.04\n/
  end

  test "the climb starts on the low B flat and holds F6, and the melody ends an octave up" do
    assert print(3) =~ ~r/\nbeat 0 +play 58 vel: 0.6, sustain: 0.4, release: 0.1\n/
    assert print(3) =~ ~r/\nbeat 9 +play 89 vel: 0.7, sustain: 2.9, release: 0.15\n/
    assert print(4) =~ ~r/\nbeat 12 +play 77 vel: 0.75, sustain: 3.9, release: 0.8\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/oboe"
    assert File.read!("LICENSE-designs.md") =~ "The oboe is measured"
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
