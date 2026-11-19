defmodule Mx.ImportTest do
  # Rendering drives the application's own clock and engine, so these tests run one at a time.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.{Import, Pass, Render}

  @moduletag :tmp_dir

  @score "examples/erbarme_dich/bwv244.39.mxl"
  @parts ["Violin=violin", "Alto=oboe", "Organo a canne=organ"]

  test "a score loads as the song mx import would write, with its synths and its tempo, writing no file" do
    before = File.ls!("examples/erbarme_dich")
    {:ok, song, imported} = Import.load(@score, part: @parts)

    assert song.tempo == 48

    assert Enum.map(song.loops, &{&1.name, &1.synth}) == [
             violin: :violin,
             alto: :oboe,
             organo_a_canne: :organ
           ]

    assert imported.out == "examples/erbarme_dich/bwv244.39.exs"
    assert "275 slurs are left out" in imported.left_out
    assert File.ls!("examples/erbarme_dich") == before

    {:ok, %{events: events}} = Pass.events(hd(song.loops), 0)
    assert events |> Enum.map(&elem(&1, 0)) |> Enum.min() == 0
  end

  test "a part given no synth plays on tri, and a part the score does not have or an unknown synth is refused with mx import's message" do
    {:ok, song, _imported} = Import.load(@score, part: ["Violin=violin"])
    assert Enum.map(song.loops, & &1.synth) == [:violin, :tri, :tri]

    assert Import.load(@score, part: ["Tenor=oboe"]) ==
             {:error,
              "no part named Tenor in bwv244.39.mxl; its parts are Violin, Alto and Organo a canne"}

    assert Import.load(@score, part: ["Alto=kazoo"]) == {:error, "unknown synth kazoo"}
  end

  test "from the first beat of bar 9, the alto and the organ sound at once and the violin rests" do
    {:ok, song, _imported} = Import.load(@score, part: @parts)
    bar_9 = 48.5

    firsts =
      for loop <- song.loops do
        {:ok, %{events: events}} = Pass.events(loop, 0)
        first = events |> Enum.map(&elem(&1, 0)) |> Enum.filter(&(&1 >= bar_9)) |> Enum.min()
        {loop.name, first}
      end

    assert firsts == [violin: 54.0, alto: 48.5, organo_a_canne: 48.5]
  end

  test "a render of a score is the render of the song mx import writes from it", %{tmp_dir: dir} do
    unwritten = Path.join(dir, "unwritten.wav")
    capture_io(fn -> assert :ok = Render.render(@score, unwritten, part: @parts, seconds: 4) end)

    song = Path.join(dir, "bwv244.39.exs")

    capture_io(fn ->
      Mix.Tasks.Mx.Import.run([@score, "--out", song | Enum.flat_map(@parts, &["--part", &1])])
    end)

    written = Path.join(dir, "written.wav")
    capture_io(fn -> assert :ok = Render.render(song, written, seconds: 4) end)

    assert File.read!(unwritten) == File.read!(written)
  end

  @tag :engine
  test "a session of a score plays without a file, takes another synth on a part, and solos a part",
       %{tmp_dir: dir} do
    {:ok, song, imported} = Import.load(@score, part: @parts)

    {:ok, session} =
      Mx.Session.start_link(path: imported.out, song: song, source: imported.source, watch: false)

    {:ok, device} = StringIO.open("")

    for {_id, pid, _type, _modules} <- Supervisor.which_children(session),
        do: Process.group_leader(pid, device)

    assert {0, {:ok, %{source: source}}} = Mx.Session.subscribe(session)
    assert source == imported.source
    assert :ok = Mx.Session.try_part(session, :alto, synth: :clarinet)
    assert :ok = Mx.Session.solo(session, [:violin])
    Supervisor.stop(session)

    refute File.exists?(imported.out)
    assert File.ls!(dir) == []
  end
end
