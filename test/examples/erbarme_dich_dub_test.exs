defmodule Mx.Examples.ErbarmeDichDubTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @song "examples/erbarme_dich/dub.exs"

  test "the dub plays the kit, the hand drums, the band, the horns and the dub's echoes on mx's synths, and no samples" do
    assert {:ok, song} = Mx.Song.load(@song)

    assert Enum.sort(Enum.map(song.loops, &{&1.name, &1.synth})) ==
             Enum.sort(
               tanpura: :tanpura,
               lead: :trombone,
               marimba: :marimba,
               kick: :kick,
               rimshot: :rimshot,
               hihat: :closed_hihat,
               tom: :mid_tom,
               bass: :double_bass,
               electric_bass: :saw,
               organ: :organ,
               harp: :harp,
               guiro: :guiro,
               harmonium: :harmonium,
               tabla: :tabla_ghe,
               snare: :snare,
               open_hihat: :open_hihat,
               crash: :crash,
               thunder: :low_conga,
               funde: :mid_conga,
               repeater: :high_conga,
               shaker: :shaker,
               trumpet: :trumpet,
               tenor_sax: :tenor_sax,
               trombone: :trombone,
               siren: :square
             )

    refute print() =~ "sample "
  end

  test "the riddim plays the one drop: the kick and the rimshot together on beat 3 of each bar, and nothing on beat 1" do
    output = print()
    in_riddim = &(&1 >= 24 and &1 < 72)
    drops = Enum.map(0..7, &(24.0 + &1 * 6 + 3))
    downbeats = Enum.map(0..7, &(24.0 + &1 * 6))

    assert "kick" |> beats(output) |> Enum.filter(in_riddim) == drops

    rimshot = "rimshot" |> beats(output) |> Enum.filter(in_riddim)
    assert Enum.all?(drops, &(&1 in rimshot))
    assert Enum.all?(downbeats, &(&1 not in rimshot))
  end

  test "the horns state the motto in octaves, then sing the alto's phrase" do
    output = print()
    motto = [74, 73, 71, 71, 70, 71, 71]
    phrase = [66, 74, 73, 71, 70, 71]

    assert output |> part("trumpet") |> notes() |> Enum.take(13) == motto ++ phrase

    for horn <- ~w(tenor_sax trombone) do
      assert output |> part(horn) |> notes() |> Enum.take(13) ==
               Enum.map(motto ++ phrase, &(&1 - 12))
    end
  end

  test "the lead trombone plays the ritornello an octave down, sliding through each beat's run, and the harmonium sings the alto's phrase over it" do
    output = print()
    lead = part(output, "lead")

    assert lead |> notes() |> Enum.take(5) == [54, 62, 59, 59, 59]
    assert lead =~ ~r/^beat 24.75 +control note: 61$/m
    assert output |> part("harmonium") |> notes() |> Enum.take(6) == [66, 74, 73, 71, 70, 71]
  end

  test "the scores guide points to the dub" do
    assert File.read!("documentation/scores.md") =~ "examples/erbarme_dich/dub.exs"
  end

  defp print, do: capture_io(fn -> Mix.Tasks.Mx.Print.run([@song]) end)

  defp part(output, name) do
    [part | _] = output |> String.split(~r/^#{name}, \d+ beats[^\n]*\n/m) |> tl()
    part |> String.split("\n\n") |> hd()
  end

  defp beats(name, output) do
    for [beat] <- Regex.scan(~r/^beat ([\d.]+)/m, part(output, name), capture: :all_but_first) do
      {beat, ""} = Float.parse(beat)
      beat
    end
  end

  defp notes(part) do
    for [note] <- Regex.scan(~r/play (\d+)/, part, capture: :all_but_first),
        do: String.to_integer(note)
  end
end
