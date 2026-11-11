defmodule Mx.Examples.PandeiroTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/pandeiro.exs"
  @virtuoso "examples/pandeiro/virtuoso.exs"

  test "the solo plays only the pandeiro" do
    for pass <- 0..13 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)

      assert Enum.sort(List.flatten(loops)) ==
               ["pandeiro_heel", "pandeiro_jingles", "pandeiro_slap", "pandeiro_thumb"]
    end

    refute print(0) =~ "sample "
  end

  test "the choro closes the thumb's bass on each bar's first beat and opens it on its second" do
    choro = print(0)
    assert choro =~ ~r/pandeiro_thumb, pass 0.*\nbeat 0 +play vel: 0.4\nbeat 1 +play vel: 0.75\n/s
    assert choro =~ ~r/pandeiro_heel, pass 0.*\nbeat 0.5 +play vel: 0.55\nbeat 1.5 +play /s
    assert choro =~ ~r/pandeiro_jingles, pass 0.*\nbeat 0.25 +play vel: 0.5\nbeat 0.75 /s
    assert choro =~ ~r/pandeiro_slap, pass 0, [^\n]*\n\z/
  end

  test "the samba de roda slaps around the first beat's bass" do
    assert print(4) =~
             ~r/pandeiro_slap, pass 4.*\nbeat 0.25 +play vel: 0.8\nbeat 0.75 +play vel: 0.8\n/s
  end

  test "the baião accents the heel of its first bar and slaps in its second" do
    baiao = print(6)
    assert baiao =~ ~r/pandeiro_heel, pass 6.*\nbeat 1.5 +play vel: 0.9\n/s
    assert baiao =~ ~r/pandeiro_slap, pass 6.*\nbeat 3.25 +play vel: 0.8\n/s
  end

  test "the forró accents the fingertips of its second bar" do
    assert print(8) =~ ~r/pandeiro_jingles, pass 8.*\nbeat 2.75 +play vel: 0.9\n/s
  end

  test "the coco slaps in each bar and doubles the thumb" do
    coco = print(10)

    assert coco =~
             ~r/pandeiro_slap, pass 10.*\nbeat 1.25 +play vel: 0.8\nbeat 2.75 +play vel: 0.8\n/s

    assert coco =~
             ~r/pandeiro_thumb, pass 10.*\nbeat 3.25 +play vel: 0.75\nbeat 3.5 +play vel: 0.75\n/s
  end

  test "the virtuoso solo starts on a coco groove and splits sixteenths into ruffs" do
    assert print(0, @virtuoso) =~
             ~r/pandeiro_slap, pass 0.*\nbeat 1.25 +play vel: 0.8\nbeat 2.75 +play vel: 0.8\n/s

    assert print(2, @virtuoso) =~
             ~r/pandeiro_heel, pass 2.*\nbeat 0.5 +play vel: 0.5\nbeat 0.875 +play /s
  end

  test "the virtuoso solo's accents every three sixteenths cross the bar line, pass after pass" do
    first = print(4, @virtuoso)
    assert first =~ ~r/pandeiro_thumb, pass 4.*\nbeat 0 +play vel: 0.9\n/s

    assert first =~
             ~r/pandeiro_slap, pass 4.*\nbeat 0.75 +play vel: 0.85\nbeat 2.25 +play vel: 0.85\nbeat 3.75 /s

    assert print(5, @virtuoso) =~ ~r/pandeiro_heel, pass 5.*\nbeat 0.5 +play vel: 0.85\n/s
    assert print(7, @virtuoso) =~ ~r/pandeiro_thumb, pass 7.*\nbeat 0 +play vel: 0.9\n/s
  end

  test "the virtuoso solo accents every fourth sextuplet" do
    assert print(15, @virtuoso) =~
             ~r/pandeiro_heel, pass 15.*\nbeat 0.333 +play vel: 0.5\nbeat 0.667 +play vel: 0.85\nbeat 1.333 +play vel: 0.85\n/s
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/solo/pandeiro.exs"
    assert File.read!("README.md") =~ "examples/pandeiro/virtuoso.exs"
    assert File.read!("LICENSE-designs.md") =~ "MeanRaccoon"
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

  @tag :timing
  @tag :tmp_dir
  @tag timeout: 200_000
  test "a minute of the virtuoso solo records without reaching full scale", %{tmp_dir: dir} do
    out = Path.join(dir, "virtuoso.wav")
    input = spawn(fn -> enter_after(60_000) end)
    leader = Process.group_leader()
    Process.group_leader(self(), input)

    try do
      Mix.Tasks.Mx.Play.run([@virtuoso, "--record", out, "--port", "57190"])
    after
      Process.group_leader(self(), leader)
    end

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  defp print(pass, song \\ @song) do
    pass = Integer.to_string(pass)
    capture_io(fn -> Mix.Tasks.Mx.Print.run([song, "--pass", pass]) end)
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
