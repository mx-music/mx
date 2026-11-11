defmodule Mx.Examples.GanzaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/ganza.exs"

  test "the solo plays the ganzá, joined by the shaker after its first section" do
    for pass <- 0..11 do
      loops = Regex.scan(~r/^(\w+), pass \d+, /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ["ganza", "shaker"]
    end

    refute print(0) =~ "shaker, pass 0, 4 beats at 100 bpm\nbeat"

    assert print(4) =~
             ~r/shaker, pass 4.*\nbeat 0 +play vel: 0.5\nbeat 0.5 +play up: 1, vel: 0.35\n/s

    refute print(0) =~ "sample "
  end

  test "the ganzá plays each pattern in sixteenths, down and up, accented on the beat" do
    one = print(0)
    assert one =~ ~r/^beat 0 +play up: 0, vel: 0.85$/m
    assert one =~ ~r/^beat 0.25 +play up: 1, vel: 0.45$/m

    assert print(4) =~
             ~r/ganza, pass 4.*\nbeat 0 +play up: 0, vel: 0.85\nbeat 0.5 +play up: 1, vel: 0.45\n/s

    assert print(6) =~
             ~r/ganza, pass 6.*\nbeat 0 +play up: 0, vel: 0.85\nbeat 0.75 +play up: 1, vel: 0.45\n/s

    assert print(8) =~ ~r/^beat 1 +play up: 1, vel: 0.85$/m
    [ganza, _shaker] = String.split(print(8), "shaker, pass")
    refute ganza =~ ~r/^beat 0.5 /m
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/ganza.exs"
    assert File.read!("LICENSE-designs.md") =~ "large shaker recordings"
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
