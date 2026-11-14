defmodule Mx.Examples.CongasTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/solo/congas.exs"

  test "the solo plays only the three congas" do
    for pass <- 0..18 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == ~w(high_conga low_conga mid_conga)
    end

    refute print(0) =~ "sample "
  end

  test "the tumbao plays heel, tip, slap, tip, heel, tip and two open tones, twice to a clave" do
    tumbao = print(0)

    assert tumbao =~
             ~r/mid_conga, pass 0, [^\n]*\nbeat 0 +play vel: 0.35, amp: 0.35\nbeat 0.25 +play vel: 0.4, mute: 1, amp: 0.7\nbeat 0.5 +play vel: 0.9, slap: 1, amp: 0.35\n/

    assert tumbao =~
             ~r/\nbeat 1.5 +play vel: 0.9, amp: 0.35\nbeat 1.75 +play vel: 0.9, amp: 0.35\nbeat 2 +play /

    assert beats(tumbao, "mid_conga") == Enum.map(0..15, &(&1 / 4))
    assert beats(tumbao, "low_conga") == []
  end

  test "the tumba's open tones fall on the clave's three side" do
    assert beats(print(2), "low_conga") == [0.75, 1.0]
    assert beats(print(4), "low_conga") == [0.75, 2.75]
  end

  test "the quinto's lock is the son clave a sixteenth late, and its tones and slaps change places in the next clave" do
    son_clave = [0, 0.75, 1.5, 2.5, 3]
    assert beats(print(6), "high_conga") == Enum.map(son_clave, &(&1 + 0.25))
    assert beats(print(7), "high_conga") == Enum.map(son_clave, &(&1 + 0.25))

    assert print(6) =~
             ~r/high_conga, pass 6, [^\n]*\nbeat 0.25 +play vel: 0.9, amp: 0.55\nbeat 1 +play vel: 0.9, slap: 1, amp: 0.55\n/

    assert print(7) =~
             ~r/high_conga, pass 7, [^\n]*\nbeat 0.25 +play vel: 0.9, slap: 1, amp: 0.55\nbeat 1 +play vel: 0.9, amp: 0.55\n/
  end

  test "the cross slaps every third sixteenth for three claves, and the next phrase ends after the third beat" do
    slaps =
      for {pass, bar} <- Enum.with_index(10..12),
          beat <- beats(print(pass), "high_conga"),
          do: bar * 4 + beat

    assert slaps == Enum.map(0..15, &(0.25 + &1 * 0.75))

    refute print(11) =~
             ~r/high_conga, pass 11, [^\n]*\n(beat [^\n]*\n)*beat \S+ +play vel: 0.9, amp: 0.55/

    assert List.last(beats(print(13), "high_conga")) == 2.25
  end

  test "the conga rolls heel and tip in thirty-seconds, and the ending is a slap on the quinto over the tumba's open tone" do
    roll = print(14)
    assert Enum.take(beats(roll, "mid_conga"), 24) == Enum.map(0..23, &(&1 / 8))

    assert roll =~
             ~r/mid_conga, pass 14, [^\n]*\nbeat 0 +play vel: 0.2, amp: 0.35\nbeat 0.125 +play vel: 0.25, mute: 1, amp: 0.7\n/

    ending = print(18)
    assert ending =~ ~r/high_conga, pass 18, [^\n]*\nbeat 0 +play vel: 0.9, slap: 1, amp: 0.55\n/
    assert ending =~ ~r/low_conga, pass 18, [^\n]*\nbeat 0 +play vel: 0.9, amp: 1.4\n/
  end

  test "the examples guide points to the solo, and the synth designs license names the recordings" do
    assert File.read!("documentation/examples.md") =~ "examples/solo/congas.exs"
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
      Mix.Tasks.Mx.Play.run([@song, "--record", out])
    after
      Process.group_leader(self(), leader)
    end

    assert %{peak: peak, clips: 0} = Mx.Recording.level(out)
    assert peak < -0.1
  end

  # The beats one drum's strokes fall on in a printed pass.
  defp beats(printed, drum) do
    [lines] =
      Regex.run(~r/^#{drum}, pass [^\n]*\n((?:beat [^\n]*\n)*)/m, printed,
        capture: :all_but_first
      )

    for [beat] <- Regex.scan(~r/^beat (\S+)/m, lines, capture: :all_but_first) do
      {value, ""} = Float.parse(beat)
      value
    end
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
