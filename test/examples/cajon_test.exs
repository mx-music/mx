defmodule Mx.Examples.CajonTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/cajon.exs"

  test "the solo plays only the cajón" do
    for pass <- 0..10 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["cajon"]]
    end

    refute print(0) =~ "sample "
  end

  test "the groove puts the bass tone on the first and third beats and a slap on the others, with ghost strokes" do
    groove = print(0)

    assert groove =~
             ~r/\nbeat 0 +play slap: 0, vel: 0.85\nbeat 0.667 +play slap: 1, vel: 0.3\nbeat 1 +play slap: 1, vel: 0.95\n/

    assert groove =~ ~r/\nbeat 2 +play slap: 0, vel: 0.85\n/
    assert groove =~ ~r/\nbeat 3 +play slap: 1, vel: 0.95\n/
  end

  test "the ghosts section fills every eighth, and the break ends on two bass tones" do
    assert length(Regex.scan(~r/^beat /m, print(4))) == 12
    assert print(10) =~ ~r/\nbeat 2 +play slap: 0, vel: 0.85\nbeat 3 +play slap: 0, vel: 0.85\n\z/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/cajon.exs"
    assert File.read!("LICENSE-designs.md") =~ "cajón recordings"
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
