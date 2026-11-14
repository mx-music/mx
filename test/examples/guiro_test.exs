defmodule Mx.Examples.GuiroTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/guiro.exs"

  test "the solo plays only the guiro" do
    for pass <- 0..11 do
      assert Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first) == [["guiro"]]
    end

    refute print(0) =~ "sample "
  end

  test "it opens on long, slow scrapes, and ends on one" do
    assert scrapes(0) == [{0, "1.6"}, {2, "1.6"}]
    assert scrapes(11) == [{0, "1.6"}]
  end

  test "the cha-cha-chá is a long scrape on each half bar and two short ones on the eighths after it" do
    chacha = [{0, "0.6"}, {1, "0.18"}, {1.5, "0.18"}, {2, "0.6"}, {3, "0.18"}, {3.5, "0.18"}]
    assert scrapes(1) == chacha
    assert scrapes(9) == chacha
  end

  test "son is long-short-short-long, and bomba three short scrapes before a long one" do
    assert scrapes(5) == [{0, "0.6"}, {1, "0.18"}, {2, "0.18"}, {3, "0.6"}]
    assert scrapes(7) == [{0, "0.18"}, {1, "0.18"}, {2, "0.18"}, {3, "0.6"}]
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/guiro.exs"
    assert File.read!("LICENSE-designs.md") =~ "güiro recordings"
  end

  # Each scrape of a pass, as its beat and its sustain.
  defp scrapes(pass) do
    for [beat, sustain] <-
          Regex.scan(~r/^beat ([\d.]+) +play vel: [\d.]+, sustain: ([\d.]+)/m, print(pass),
            capture: :all_but_first
          ) do
      {number, _} = Float.parse(beat)
      {if(number == trunc(number), do: trunc(number), else: number), sustain}
    end
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
