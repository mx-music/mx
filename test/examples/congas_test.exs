defmodule Mx.Examples.CongasTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/congas/solo.exs"

  test "the solo plays only the three congas" do
    for pass <- 0..7 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ~w(high_conga low_conga mid_conga)
    end

    refute print(0) =~ "sample "
  end

  test "the tumbao plays muted strokes, a slap on the second beat and open tones on the fourth" do
    tumbao = print(0)
    assert tumbao =~ ~r/mid_conga, pass 0, [^\n]*\nbeat 0 +play vel: 0.6, mute: 1, amp: 0.5\n/
    assert tumbao =~ ~r/\nbeat 1 +play vel: 0.9, slap: 1, amp: 0.5\n/
    assert tumbao =~ ~r/low_conga, pass 0, [^\n]*\nbeat 3.5 +play vel: 0.8, amp: 0.5\n/
  end

  test "the quinto answers and solos with slaps and open tones, and the tumbao comes back at its softest" do
    assert print(2) =~
             ~r/high_conga, pass 2, [^\n]*\nbeat 1.5 +play vel: 0.9, slap: 1, amp: 0.5\n/

    assert print(4) =~
             ~r/high_conga, pass 4, [^\n]*\nbeat 0 +play vel: 0.8, amp: 0.5\nbeat 0.5 +play vel: 0.9, slap: 1/

    assert print(6) =~ ~r/mid_conga, pass 6, [^\n]*\nbeat 0 +play vel: 0.3, amp: 0.5\n/
  end

  test "the ending runs down the three drums to a slap on the quinto" do
    ending = print(7)
    assert ending =~ ~r/high_conga, pass 7, [^\n]*\nbeat 0 +play vel: 0.8, amp: 0.5\n/
    assert ending =~ ~r/mid_conga, pass 7, [^\n]*\nbeat 1 +play vel: 0.8, amp: 0.5\n/
    assert ending =~ ~r/low_conga, pass 7, [^\n]*\nbeat 2 +play vel: 0.8, amp: 0.5\n/
    assert ending =~ ~r/\nbeat 3 +play vel: 0.9, slap: 1, amp: 0.5\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/congas"
    assert File.read!("LICENSE-designs.md") =~ "tumba, conga and quinto recordings"
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
