defmodule Mx.Examples.CelloTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/cello.exs"

  test "the solo plays only the cello" do
    for pass <- 0..3 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["cello"]]
    end

    refute print(0) =~ "sample "
  end

  test "the licence notes name the Iowa recordings the cello's onsets and body come from" do
    notes = File.read!("LICENSE-designs.md")

    assert notes =~
             "https://theremin.music.uiowa.edu/MIScello.html, which may be downloaded and used for any projects, without restrictions"

    assert notes =~ "mxs plays eighteen onsets cut from Iowa's bowed cello notes"

    assert notes =~
             "the cello body's impulse response, measured from the noise Iowa's bowed notes hold between their harmonics"
  end

  test "the prelude breaks each chord across the strings over the open G, eight notes to a bow, without sliding" do
    assert print(0) =~
             ~r/\nbeat 0 +play 43 vel: 0.65, sustain: 1.9, release: 0.2, vibrato: 0\nbeat 0.25 +control note: 50, note_slide: 0.01\nbeat 0.5 +control note: 59, note_slide: 0.01\n/

    assert print(0) =~ ~r/\nbeat 2 +play 43 vel: 0.55, sustain: 1.9,/
    assert print(0) =~ ~r/\nbeat 12 +play 43 .*\nbeat 12.25 +control note: 55, note_slide: 0.01\n/
  end

  test "the cantabile slides audibly on its shifts, and swells its long notes with vibrato" do
    assert print(1) =~ ~r/\nbeat 1.5 +control note: 55, note_slide: 0.1\n/

    assert print(1) =~
             ~r/\nbeat 2 +play 59 vel: 0.6, amp: 0.6, sustain: 1.9, release: 0.2, vibrato: 0.08\n/
  end

  test "the walking bass plucks a note each beat, louder on each root, and lets it ring" do
    assert print(2) =~
             ~r/\nbeat 8 +play 36 vel: 0.8, pizz: 1, sustain: 2\nbeat 9 +play 40 vel: 0.6, pizz: 1, sustain: 2\n/
  end

  test "the ending climbs to a long high D and settles on the low G, swelled" do
    assert print(3) =~
             ~r/\nbeat 4 +play 74 vel: 0.7, amp: 0.6, sustain: 2.9, release: 0.2, vibrato: 0.1\n/

    assert print(3) =~
             ~r/\nbeat 12 +play 43 vel: 0.7, amp: 0.6, sustain: 3.9, release: 0.2, vibrato: 0.08\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/cello.exs"
    assert File.read!("LICENSE-designs.md") =~ "The cello is measured"
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
