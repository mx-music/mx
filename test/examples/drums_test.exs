defmodule Mx.Examples.DrumsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/drums/solo.exs"
  @kit ~w(closed_hihat crash high_tom kick low_tom mid_tom open_hihat snare)

  test "the solo plays only the drum kit" do
    for pass <- 0..6 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == @kit
    end

    refute print(0) =~ "sample "
  end

  test "it opens on a crash, the hi-hat opens and the pedal closes it, and the snare plays its softest and hardest strokes" do
    assert print(0) =~ ~r/crash, pass 0, [^\n]*\nbeat 0 +play vel: 1, amp: 0.5\n/

    assert print(2) =~
             ~r/open_hihat, pass 2, [^\n]*\nbeat 1.5 +play vel: 0.55, sustain: 0.5, release: 0.05, amp: 0.5\nbeat 3.5 +play /

    ghosts = print(4)
    assert ghosts =~ ~r/snare, pass 4, [^\n]*\nbeat 0 +play vel: 0.3, amp: 0.5\n/
    assert ghosts =~ ~r/\nbeat 1 +play vel: 1, amp: 0.5\n/
  end

  test "the fill goes down the toms, and the last crash is choked after three beats" do
    fill = print(5)
    assert fill =~ ~r/high_tom, pass 5, [^\n]*\nbeat 0 +play vel: 0.75, amp: 0.5\n/
    assert fill =~ ~r/mid_tom, pass 5, [^\n]*\nbeat 1 +play vel: 0.75, amp: 0.5\n/
    assert fill =~ ~r/low_tom, pass 5, [^\n]*\nbeat 2 +play vel: 0.75, amp: 0.5\n/

    assert print(6) =~
             ~r/crash, pass 6, [^\n]*\nbeat 0 +play vel: 1, sustain: 3, release: 0.1, amp: 0.5\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/drums"
    license = File.read!("LICENSE-designs.md")
    assert license =~ "snare drum recordings"
    assert license =~ "crash cymbal recordings"
    assert license =~ "hi-hat recordings"
    assert license =~ "tom recordings"
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
