defmodule Mx.Examples.CabasaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/cabasa.exs"

  test "the solo plays only the cabasa, in sixteenths" do
    for pass <- 0..7 do
      output = print(pass)
      assert Regex.scan(~r/^(\w+), pass /m, output, capture: :all_but_first) == [["cabasa"]]
      assert length(Regex.scan(~r/^beat /m, output)) == 32
    end

    refute print(0) =~ "sample "
  end

  test "the pulse accents each beat, then the bossa nova figure" do
    assert print(0) =~
             ~r/\nbeat 0 +play vel: 0.8\nbeat 0.25 +play vel: 0.4\n.*\nbeat 1 +play vel: 0.8\n/s

    bossa = print(2)

    assert bossa =~
             ~r/\nbeat 1 +play vel: 0.4\n.*\nbeat 1.5 +play vel: 0.8\n.*\nbeat 3 +play vel: 0.8\n/s

    assert bossa =~
             ~r/\nbeat 4.5 +play vel: 0.8\n.*\nbeat 6 +play vel: 0.8\n.*\nbeat 7 +play vel: 0.8\n/s
  end

  test "the turns play the figure as rubs" do
    turns = print(6)
    assert length(Regex.scan(~r/rub: 1, sustain: 0.25/, turns)) == 6
    assert turns =~ ~r/\nbeat 1.5 +play vel: 0.8, rub: 1, sustain: 0.25\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/cabasa.exs"
    assert File.read!("LICENSE-designs.md") =~ "cabasa recordings"
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
