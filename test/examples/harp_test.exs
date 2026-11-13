defmodule Mx.Examples.HarpTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/harp.exs"

  test "the solo plays only the harp" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["harp"]]
    end

    refute print(0) =~ "sample "
  end

  test "the joropo's bass marks three beats a bar while the arpeggio groups its eighths in threes" do
    joropo = print(0)

    assert joropo =~
             ~r/\nbeat 0 +play 45 vel: 0.7, sustain: 0.9\nbeat 0 +play 69 vel: 0.75, sustain: 0.9\n/

    assert joropo =~
             ~r/\nbeat 1 +play 57 vel: 0.7, sustain: 0.9\nbeat 1 +play 76 vel: 0.5, sustain: 0.9\n/

    assert joropo =~ ~r/\nbeat 1.5 +play 81 vel: 0.75, sustain: 0.9\n/
  end

  test "the chords are left to ring" do
    assert print(4) =~ ~r/\nbeat 0 +play 45 vel: 0.6, sustain: 1000\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/harp.exs"
    assert File.read!("LICENSE-designs.md") =~ "The harp is measured"
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
