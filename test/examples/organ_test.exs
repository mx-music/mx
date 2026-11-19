defmodule Mx.Examples.OrganTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/organ.exs"

  test "the solo plays only the organ" do
    for pass <- 0..5 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["organ"]]
    end

    refute print(0) =~ "sample "
  end

  test "the quiet set holds chords over a moving bass, and the loud set comes in after" do
    quiet = print(0)
    assert quiet =~ ~r/\nbeat 0 +play 60 loud: 0, sustain: 3.8\n/

    assert quiet =~
             ~r/\nbeat 0 +play 36 loud: 0, sustain: 0.9\nbeat 1 +play 40 loud: 0, sustain: 0.9\n/

    assert print(2) =~ ~r/\nbeat 0 +play 60 loud: 1, sustain: 3.8\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/organ.exs"
    assert File.read!("LICENSE-designs.md") =~ "Simon Dalzell"
  end

  test "the organ takes vel" do
    path = Path.join(System.tmp_dir!(), "organ_vel_#{System.unique_integer([:positive])}.exs")
    File.write!(path, "import Mx\nsong(music: part(:a, note(60, 1, vel: 1), synth: :organ))\n")

    assert capture_io(fn -> Mix.Tasks.Mx.Print.run([path]) end) =~ ~r/play 60 vel: 1\b/
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
