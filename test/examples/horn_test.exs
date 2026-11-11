defmodule Mx.Examples.HornTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/horn.exs"

  test "the solo plays only the French horn" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["horn"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the melody has a little vibrato, and comes back an octave lower" do
    assert print(0) =~
             ~r/\nbeat 4 +play 70 vel: 0.55, sustain: 2.85, release: 0.3, vibrato: 0.05\n/

    assert print(1) =~
             ~r/\nbeat 4 +play 58 vel: 0.55, sustain: 2.85, release: 0.3, vibrato: 0.05\n/
  end

  test "the calls are tongued short and answered a fourth lower, then come at its softest and loudest" do
    assert print(2) =~ ~r/\nbeat 0.75 +play 63 vel: 0.75, sustain: 0.15, release: 0.05\n/
    assert print(2) =~ ~r/\nbeat 4.75 +play 58 vel: 0.75, sustain: 0.15, release: 0.05\n/
    assert print(3) =~ ~r/\nbeat 0 +play 63 vel: 0.2, sustain: 3.6, release: 0.3\n/
    assert print(3) =~ ~r/\nbeat 8 +play 63 vel: 1, sustain: 3.6, release: 0.3\n/
  end

  test "the ending runs down the Eb major chord to a held low Eb2" do
    assert print(4) =~ ~r/\nbeat 0 +play 75 vel: 0.75, sustain: 0.3, release: 0.05\n/
    assert print(4) =~ ~r/\nbeat 4.5 +play 39 vel: 0.85, sustain: 11.0, release: 0.5\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/horn.exs"

    assert File.read!("LICENSE-designs.md") =~
             "The French horn, horn, is measured"
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
