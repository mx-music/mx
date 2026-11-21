defmodule Mx.Examples.EffectsTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @sections %{
    "bitcrusher" => 5,
    "bpf" => 5,
    "chorus" => 5,
    "compressor" => 5,
    "distortion" => 5,
    "echo" => 6,
    "flanger" => 5,
    "hpf" => 5,
    "level" => 4,
    "lpf" => 5,
    "pan" => 5,
    "ping_pong" => 6,
    "pitch_shift" => 6,
    "reverb" => 5,
    "rlpf" => 5,
    "slicer" => 6,
    "tremolo" => 6,
    "wobble" => 5
  }

  test "the folder holds a song for each effect mx ships, and order.exs" do
    # Effects that tests register join the catalog, so only mxs's own effects are listed.
    {_synths, _note, _sample, native, _effect, _input} = Mx.Engine.Mxs.Native.catalog()
    effects = Enum.map(native, fn {name, _specs} -> name end)

    assert Enum.sort(effects) == Enum.sort(Map.keys(@sections))

    assert "examples/effects/*.exs" |> Path.wildcard() |> Enum.map(&Path.basename(&1, ".exs")) ==
             Enum.sort(["order" | effects])
  end

  for {effect, sections} <- @sections do
    @effect effect
    @count sections

    test "#{effect}.exs plays one part through #{effect} alone, for 20 to 60 seconds" do
      [header | _notes] = String.split(print(@effect), "\n")

      assert [_all, beats, bpm, effects] =
               Regex.run(~r/^\w+, ([\d.]+) beats at ([\d.]+) bpm, through (.+)$/, header)

      assert effects |> String.split(" then ") |> Enum.map(&hd(String.split(&1, " "))) == [
               @effect
             ]

      seconds = number(beats) * 60 / number(bpm)
      assert seconds >= 20 and seconds <= 60
    end

    test "#{effect}.exs says what to listen for in each of its #{sections} sections, in order" do
      doc = File.read!(path(@effect))
      numbered = Regex.scan(~r/^  (\d+)\. /m, doc, capture: :all_but_first)

      assert numbered == for(section <- 1..@count, do: [Integer.to_string(section)])
    end

    @tag :engine
    @tag :tmp_dir
    test "every section of #{effect}.exs after the first sounds different from it", %{
      tmp_dir: dir
    } do
      {frames, peak} = render(@effect, dir)

      [first | later] =
        frames |> Enum.chunk_every(div(length(frames), @count)) |> Enum.take(@count)

      for section <- later do
        assert difference(first, section) > peak / 10
      end
    end
  end

  test "order.exs plays one phrase through a distortion and a reverb, then through the two reversed" do
    assert [driven, room] = print("order") |> String.split("\n\n", trim: true)
    assert driven =~ ~r/^driven_first, .* through distortion \(.*\) then reverb \(/
    assert room =~ ~r/^room_first, .* through reverb \(.*\) then distortion \(/
  end

  @tag :engine
  @tag :tmp_dir
  test "the two orders of order.exs sound different", %{tmp_dir: dir} do
    {frames, peak} = render("order", dir)
    [first, second] = frames |> Enum.chunk_every(div(length(frames), 2)) |> Enum.take(2)

    assert difference(first, second) > peak / 10
  end

  test "the guides describe the folder and name each effect's song" do
    assert File.read!("documentation/examples.md") =~ "`examples/effects` holds one short song"
    guide = File.read!("documentation/instruments.md")

    for effect <- Map.keys(@sections) do
      assert guide =~ "`examples/effects/#{effect}.exs`"
    end
  end

  defp path(name), do: "examples/effects/#{name}.exs"

  defp print(name), do: capture_io(fn -> Mix.Tasks.Mx.Print.run([path(name)]) end)

  defp number(text) do
    {number, ""} = Float.parse(text)
    number
  end

  # The frames of a render with nothing kept after the music ends, and its peak; it must not clip.
  defp render(name, dir) do
    out = Path.join(dir, name <> ".wav")
    capture_io(fn -> assert :ok = Mx.Render.render(path(name), out, ring_out: false) end)
    assert %{clips: 0} = Mx.Recording.level(out)

    {:ok, %{channels: 2, bits: 32}, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    {frames, frames |> Enum.map(fn {left, right} -> max(abs(left), abs(right)) end) |> Enum.max()}
  end

  # The largest difference between two sections at the same frame, on either side.
  defp difference(first, second) do
    first
    |> Enum.zip_with(second, fn {a, b}, {c, d} -> max(abs(a - c), abs(b - d)) end)
    |> Enum.max()
  end
end
