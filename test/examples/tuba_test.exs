defmodule Mx.Examples.TubaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/tuba.exs"

  test "the solo plays only the tuba" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["tuba"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the oom-pah bass is short, root then fifth, and the walking bass is held" do
    assert print(0) =~ ~r/\nbeat 2 +play 29 vel: 0.75, sustain: 0.3, release: 0.05\n/
    assert print(1) =~ ~r/\nbeat 1 +play 38 vel: 0.65, sustain: 0.8, release: 0.1\n/
  end

  test "the melody climbs to C4, and the long notes come at its softest then its loudest" do
    assert print(2) =~ ~r/\nbeat 12 +play 60 vel: 0.6, sustain: 1.85, release: 0.2\n/
    assert print(3) =~ ~r/\nbeat 0 +play 41 vel: 0.2, sustain: 3.6, release: 0.3\n/
    assert print(3) =~ ~r/\nbeat 8 +play 41 vel: 1, sustain: 3.6, release: 0.3\n/
  end

  test "the ending runs down to a held low F1" do
    assert print(4) =~ ~r/\nbeat 3 +play 29 vel: 0.85, sustain: 12.5, release: 0.5\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/tuba.exs"

    assert File.read!("LICENSE-designs.md") =~
             "The tuba is measured"
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
