defmodule Mx.Examples.ViolinTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/violin/solo.exs"

  test "the solo plays only the violin" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["violin"]]
    end

    refute print(0) =~ "sample "
  end

  test "the cantabile slurs its notes into one bow, and swells and eases its long notes" do
    assert print(0) =~
             ~r/\nbeat 0 +play 62 vel: 0.5, amp: 0.6, sustain: 1.9, release: 0.15, vibrato: 0.08\nbeat 0 +control amp: 1, amp_slide: 1.0\nbeat 1 +control amp: 0.5, amp_slide: 1.0\n/

    assert print(0) =~
             ~r/\nbeat 2 +play 65 vel: 0.5, sustain: 1.9, release: 0.15, vibrato: 0\nbeat 2.5 +control note: 64, note_slide: 0.01\n/

    assert print(0) =~ ~r/\nbeat 3.5 +control note: 69, note_slide: 0.08\n/
  end

  test "the bariolage crosses to the open A string in separate bows, louder the second time" do
    assert print(1) =~
             ~r/\nbeat 0 +play 77 vel: 0.65, sustain: 0.2, release: 0.05, vibrato: 0\nbeat 0.25 +play 69 vel: 0.5,/

    assert print(2) =~
             ~r/\nbeat 0.25 +play 69 vel: 0.6, sustain: 0.2, release: 0.05, vibrato: 0\n/
  end

  test "the scales slur eight sixteenths to a bow, then the arpeggios are short" do
    assert print(3) =~
             ~r/\nbeat 0 +play 62 vel: 0.5, sustain: 1.9, release: 0.15, vibrato: 0\nbeat 0.25 +control note: 64, note_slide: 0.01\n/

    assert print(3) =~ ~r/\nbeat 2 +play 76 vel: 0.65,/
    assert print(3) =~ ~r/\nbeat 8 +play 62 vel: 0.6, sustain: 0.12, release: 0.05, vibrato: 0\n/
  end

  test "the plucked passage plucks its notes down to the open G and lets them ring" do
    assert print(4) =~ ~r/\nbeat 4 +play 55 vel: 0.8, pizz: 1, sustain: 4\n/
  end

  test "the ending shifts up in one bow to D7, held with vibrato" do
    assert print(5) =~ ~r/\nbeat 1 +control note: 81, note_slide: 0.08\n/

    assert print(5) =~
             ~r/\nbeat 4 +play 98 vel: 0.7, amp: 0.6, sustain: 7.9, release: 0.15, vibrato: 0.1\n/
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/violin"
    assert File.read!("LICENSE-designs.md") =~ "The violin is measured"
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
