defmodule Mx.Examples.AgogoTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/agogo.exs"

  test "the solo plays the agogô's two bells alone" do
    for pass <- 0..21 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ["high_agogo", "low_agogo"]
    end

    refute print(0) =~ "sample "
  end

  test "the solo goes from the samba bell pattern to partido alto, maracatu and accents" do
    assert print(0) =~ ~r/high_agogo, pass 0.*\nbeat 1 +play vel: 0.6\nbeat 2 +play /s
    assert print(4) =~ ~r/low_agogo, pass 4.*\nbeat 2.5 +play vel: 0.7\n/s
    assert print(8) =~ ~r/low_agogo, pass 8.*\nbeat 0 +play vel: 0.9\n/s
    accents = print(12)
    assert accents =~ ~r/^beat 3.5 +play vel: 1$/m
    assert accents =~ ~r/^beat 3 +play vel: 0.3$/m
  end

  test "the solo ends with four samba patterns, splitting a cell of two strokes in half" do
    one = print(14)

    assert one =~
             ~r/high_agogo, pass 14.*\nbeat 0 +play vel: 0.8\nbeat 0.5 +play vel: 0.55\nbeat 2 /s

    assert one =~ ~r/low_agogo, pass 14.*\nbeat 1 +play vel: 0.55\nbeat 3 /s

    three = print(18)

    assert three =~
             ~r/high_agogo, pass 18.*\nbeat 1.5 +play .*\nbeat 2.25 +play .*\nbeat 2.75 +play /s

    assert three =~ ~r/low_agogo, pass 18.*\nbeat 1 +play .*\nbeat 1.75 +play /s
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/agogo.exs"
    assert File.read!("LICENSE-designs.md") =~ "Versilian Community Sample Library"
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
