defmodule Mx.Examples.TenorSaxTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/tenor_sax.exs"

  test "the solo plays only the tenor saxophone" do
    for pass <- 0..4 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [
               ["tenor_sax"]
             ]
    end

    refute print(0) =~ "sample "
  end

  test "the choro runs in sixteenths, the second time a fourth lower" do
    assert print(0) =~ ~r/\nbeat 0.25 +play 67 vel: 0.55, sustain: 0.2, release: 0.05\n/
    assert print(1) =~ ~r/\nbeat 1 +play 67 vel: 0.7, sustain: 0.8, release: 0.05\n/
  end

  test "the slow phrase has full vibrato, then comes back at its softest and its loudest" do
    assert print(2) =~ ~r/\nbeat 2 +play 65 vel: 0.6, sustain: 1.85, release: 0.2, vibrato: 1\n/
    assert print(3) =~ ~r/\nbeat 0 +play 60 vel: 0.2, sustain: 1.85, release: 0.2, vibrato: 0.5\n/
    assert print(3) =~ ~r/\nbeat 8 +play 57 vel: 1, sustain: 3.85, release: 0.2, vibrato: 0.5\n/
  end

  test "the last run climbs down from E5 to its low A flat, held" do
    assert print(4) =~ ~r/\nbeat 0 +play 76 vel: 0.65, sustain: 0.2, release: 0.05\n/

    assert print(4) =~
             ~r/\nbeat 4.75 +play 44 vel: 0.8, sustain: 10.75, release: 0.4, vibrato: 1\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/tenor_sax.exs"

    assert File.read!("LICENSE-designs.md") =~
             "The tenor saxophone, tenor_sax, is measured"
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
