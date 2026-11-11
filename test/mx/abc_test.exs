defmodule Mx.ABCTest do
  use ExUnit.Case, async: true

  alias Mx.{ABC, Audiveris}

  @moduletag :tmp_dir

  @header """
  %%rokot-abc 0.1
  X:1
  M:2/4
  L:1/8
  K:Ab
  V:1 clef=treble
  V:2 clef=bass
  """

  test "each numbered voice is a part, played in the key with accidentals lasting to the bar line",
       %{tmp_dir: dir} do
    score =
      read(dir, [
        @header <>
          """
          [V:1] A =A A c | A2 c2 |
          [V:2] [A,,A,]4 | z4 |
          """
      ])

    assert [right, left] = score.parts
    assert heads(right) == [["ab4"], ["a4"], ["a4"], ["c5"], ["ab4"], ["c5"]]
    assert heads(left) == [["ab2", "ab3"]]
    assert Enum.map(right.bars, &bar_length/1) == [2.0, 2.0]
  end

  test "a voice named after a staff, such as 2b, is a second voice of that staff's part", %{
    tmp_dir: dir
  } do
    score =
      read(dir, [
        @header <>
          """
          V:2b
          [V:1] c4 |
          [V:2] C,4 |
          [V:2b] z2 E,2 |
          """
      ])

    assert length(score.parts) == 2
    [_right, left] = score.parts
    assert [voices] = Enum.map(left.bars, & &1.voices)
    assert length(voices) == 2
  end

  test "systems follow each other, a tie carries into the next system, and a triplet fits its bar",
       %{tmp_dir: dir} do
    first = @header <> "[V:1] c4- |\n[V:2] z4 |\n"
    second = @header <> "[V:1] c (3d/e/f/ g2 |\n[V:2] z4 |\n"

    [right, _left] = read(dir, [first, second]).parts

    assert length(right.bars) == 2
    assert [[tied], [continued] | _] = notes(right)
    assert tied.tie and continued.continues
    assert heads(right) == [["c5"], ["c5"], ["db5"], ["eb5"], ["f5"], ["g5"]]
    assert_in_delta right.bars |> Enum.at(1) |> bar_length(), 2.0, 1.0e-9
  end

  test "a bar written short in one part ends with a rest, so every part's bar lasts as long" do
    xml = ABC.musicxml([@header <> "[V:1] c3 | c4 |\n[V:2] C,4 | C,4 |\n"])

    [first_part, _second_part] = Regex.scan(~r/<part id=.*?<\/part>/s, xml)
    assert hd(first_part) =~ "<note><rest/><duration>48</duration><voice>1</voice></note>"
  end

  test "repeats and endings are played in order", %{tmp_dir: dir} do
    score =
      read(dir, [
        @header <>
          """
          [V:1] |: c4 |[1 d4 :|[2 e4 |] f4 |
          [V:2] |: z4 |[1 z4 :|[2 z4 |] z4 |
          """
      ])

    assert score.order == [1, 2, 1, 3, 4]
  end

  test "the tempo and the dynamics are kept", %{tmp_dir: dir} do
    score =
      read(dir, [
        String.replace(@header, "K:Ab", "Q:1/4=100\nK:Ab") <>
          """
          [V:1] !f!c4 | !p!c4 |
          [V:2] z4 | z4 |
          """
      ])

    assert score.tempo == 100
    [right, _left] = score.parts
    assert right |> notes() |> Enum.map(fn [note] -> note.mark end) == ["f", "p"]
  end

  test "the systems the model read from three pages of a rag make one score, its repeats taken",
       %{tmp_dir: dir} do
    systems =
      "test/support/scans/abc/system-*.abc"
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&File.read!/1)

    score = read(dir, systems)

    assert Enum.map(score.parts, &length(&1.bars)) == [87, 87]
    assert length(score.order) == 149
    assert score.tempo == 100
  end

  defp read(dir, systems) do
    path = Path.join(dir, "score.mxl")
    Audiveris.write_mxl(path, ABC.musicxml(systems))
    {:ok, score} = Mx.Score.read(path)
    score
  end

  defp notes(part) do
    for bar <- part.bars,
        voice <- bar.voices,
        group <- voice,
        group.notes != [],
        do:
          Enum.map(
            group.notes,
            &(Map.put(&1, :length, group.length) |> Map.put(:mark, group.mark))
          )
  end

  defp heads(part), do: part |> notes() |> Enum.map(&Enum.map(&1, fn note -> note.name end))

  defp bar_length(bar) do
    bar.voices |> hd() |> Enum.map(& &1.length) |> Enum.sum()
  end
end
