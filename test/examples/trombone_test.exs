defmodule Mx.Examples.TromboneTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/trombone.exs"

  test "the solo plays only the trombone" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["trombone"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the legato phrases glide from note to note, the second time a fourth lower" do
    assert print(0) =~
             ~r/\nbeat 0 +play 53 vel: 0.6, release: 0.3, note_slide: 0.3, sustain: 3.7\n/

    assert print(0) =~ ~r/\nbeat 2 +control note: 58\n/

    assert print(1) =~
             ~r/\nbeat 0 +play 48 vel: 0.6, release: 0.3, note_slide: 0.3, sustain: 3.7\n/
  end

  test "the march is in short notes, and the long notes come at its softest then its loudest" do
    assert print(2) =~ ~r/\nbeat 1.5 +play 53 vel: 0.8, sustain: 0.25, release: 0.05\n/
    assert print(3) =~ ~r/\nbeat 0 +play 53 vel: 0.2, sustain: 3.6, release: 0.3, vibrato: 0.1\n/
    assert print(3) =~ ~r/\nbeat 8 +play 53 vel: 1, sustain: 3.6, release: 0.3, vibrato: 0.1\n/
  end

  test "the ending glides from F2 up to F4" do
    assert print(4) =~ ~r/\nbeat 0 +play 41 vel: 0.9, release: 0.3, note_slide: 2, sustain: 15\n/
    assert print(4) =~ ~r/\nbeat 4 +control note: 65\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/trombone.exs"

    assert File.read!("LICENSE-designs.md") =~
             "The trombone is measured"
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

  # An input device that answers the first line asked for after a delay, as a person pressing
  # Enter would.
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
