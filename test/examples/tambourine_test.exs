defmodule Mx.Examples.TambourineTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/tambourine.exs"

  test "the solo plays only the tambourine, struck and shaken" do
    for pass <- 0..7 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ~w(tambourine tambourine_shake)
    end

    refute print(0) =~ "sample "
  end

  test "the roll starts and ends on a stroke, and the backbeat shakes in eighths and strikes on two and four" do
    roll = print(0)

    assert roll =~
             ~r/tambourine, pass 0, [^\n]*\nbeat 0 +play vel: 0.6, amp: 0.5\nbeat 3.5 +play vel: 0.6, amp: 0.5\n/

    assert roll =~
             ~r/tambourine_shake, pass 0, [^\n]*\nbeat 0 +play vel: 0.45, sustain: 3.5, amp: 0.5\n/

    backbeat = print(1)

    assert backbeat =~
             ~r/tambourine, pass 1, [^\n]*\nbeat 1 +play vel: 1, amp: 0.5\nbeat 3 +play vel: 1, amp: 0.5\n/

    assert length(Regex.scan(~r/sustain: 0.25/, backbeat)) == 8
  end

  test "the tarantella plays triplets with the palm on each beat, and the soft strokes are the softest" do
    assert print(3) =~
             ~r/\nbeat 0 +play vel: 1, amp: 0.5\nbeat 0.333 +play vel: 0.45, amp: 0.5\nbeat 0.667 +play vel: 0.45, amp: 0.5\nbeat 1 +play vel: 1/

    assert print(4) =~ ~r/\nbeat 0.333 +play vel: 0.45, amp: 0.5\nbeat 1 +play vel: 1/
    assert print(6) =~ ~r/tambourine, pass 6, [^\n]*\nbeat 0 +play vel: 0.3, amp: 0.5\n/
  end

  test "the ending's roll grows into a last stroke of the flat hand" do
    ending = print(7)

    assert ending =~
             ~r/\nbeat 0 +play vel: 0.3, sustain: 1.0, amp: 0.5\nbeat 1 +play vel: 0.5, sustain: 1.0, amp: 0.5\nbeat 2 +play vel: 0.7, sustain: 1.0/

    assert ending =~ ~r/tambourine, pass 7, [^\n]*\nbeat 3 +play vel: 1, amp: 0.5\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/tambourine.exs"
    assert File.read!("LICENSE-designs.md") =~ "tambourine recordings"
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
