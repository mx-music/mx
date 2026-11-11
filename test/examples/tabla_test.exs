defmodule Mx.Examples.TablaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/tabla/solo.exs"
  @synths ~w(tabla_ghe tabla_ke tabla_na tabla_te tabla_tun)

  test "the solo plays the tabla alone" do
    for pass <- 0..6 do
      loops = Regex.scan(~r/^(\w+), pass /m, print(pass), capture: :all_but_first)
      assert Enum.sort(List.flatten(loops)) == @synths
    end

    refute print(0) =~ "sample "
  end

  test "the theka plays no ghe in its khali, beats 9 to 12" do
    for pass <- [0, 1, 4, 5, 6] do
      [ghe] = Regex.run(~r/tabla_ghe, pass .*?\n\n/s, print(pass) <> "\n\n")
      beats = Regex.scan(~r/^beat (\d+)\s+play/m, ghe, capture: :all_but_first)
      beats = Enum.map(List.flatten(beats), &String.to_integer/1)
      assert beats != []
      refute Enum.any?(beats, &(&1 in 8..11)), "pass #{pass} plays ghe on #{inspect(beats)}"
    end
  end

  test "the variation splits the theka's beats in two, and the bends slide the bayan up" do
    assert print(2) =~ ~r/tabla_te, pass 2.*\nbeat 0.5 +play vel: 0.45\n/s
    assert print(2) =~ ~r/tabla_ke, pass 2.*\nbeat 8.5 +play vel: 0.5\n/s
    assert print(4) =~ ~r/^beat 1 +play vel: 0.65, note_slide: 0.5\nbeat 1 +control note: 44.25$/m
  end

  test "the README points to the solo, and the synth designs license names the recordings" do
    assert File.read!("README.md") =~ "examples/tabla"
    assert File.read!("LICENSE-designs.md") =~ "tabla bols"
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
