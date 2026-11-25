defmodule Mx.CLITest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Export

  @moduletag :tmp_dir

  @tasks ~w(bench devices export fit hum import levels measure page parts play print spectrogram video waveform) ++
           ["samples download"]

  defp beat(dir) do
    song = Path.join(dir, "beat.exs")

    File.write!(song, """
    import Mx
    song(music: together([part(:kick, steps("x...", 1), synth: :kick), part(:bass, note(:c2, 4), synth: :tri)]))
    """)

    song
  end

  test "mx export writes the file mix mx.export writes, and prints the same", %{tmp_dir: dir} do
    song = beat(dir)
    out = Path.join(dir, "beat.musicxml")

    task = capture_io(fn -> Export.run([song]) end)
    written = File.read!(out)
    File.rm!(out)

    {status, command} = with_io(fn -> Mx.CLI.run(["export", song]) end)

    assert status == 0
    assert command == task
    assert File.read!(out) == written
  end

  test "a command that fails prints its task's message to standard error and exits with status 1",
       %{
         tmp_dir: dir
       } do
    missing = Path.join(dir, "missing.exs")
    message = assert_raise(Mix.Error, fn -> Export.run([missing]) end).message

    {status, error} = with_io(:stderr, fn -> Mx.CLI.run(["export", missing]) end)

    assert status == 1
    assert error == message <> "\n"
  end

  test "mx with no arguments, or a command it does not know, lists every command with its task's description and exits with status 1" do
    for argv <- [[], ["frobnicate"]] do
      {status, listing} = with_io(:stderr, fn -> Mx.CLI.run(argv) end)

      assert status == 1

      for name <- @tasks do
        module = Mix.Task.get("mx." <> String.replace(name, " ", "."))

        assert listing =~
                 "  mx #{String.pad_trailing(name, 16)}  # #{Mix.Task.shortdoc(module)}\n"
      end

      listed = Regex.scan(~r/^  mx /m, listing)
      assert length(listed) == length(@tasks)
    end
  end

  test "mx help prints a command's documentation, as mix help prints its task's" do
    {status, doc} = with_io(fn -> Mx.CLI.run(["help", "samples", "download"]) end)

    assert status == 0
    assert doc =~ "mx samples download"
    words = String.replace(doc, ~r/\s+/, " ")
    assert words =~ "Downloads a collection of samples into the user's cache"
    assert words =~ "Files already downloaded are skipped"
  end

  test "mx song.exs plays a song, as mx play song.exs does", %{tmp_dir: dir} do
    song = beat(dir)

    for argv <- [[song], ["play", song]] do
      out = Path.join(dir, "#{length(argv)}.wav")

      {status, output} =
        with_io(fn -> Mx.CLI.run(argv ++ ["--render", out, "--seconds", "1"]) end)

      assert status == 0
      assert output =~ "to #{out}"
      assert File.exists?(out)
    end
  end
end
