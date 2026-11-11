defmodule Mx.AudiverisTest do
  use ExUnit.Case, async: true

  alias Mx.Audiveris

  @moduletag :tmp_dir

  test "joins pages in order and keeps parts in step where a page lacks one", %{tmp_dir: dir} do
    first = page(dir, "first.mxl", [{"' Tenore.", [:c4, :d4]}, {"Basso.“", [:c3, :d3]}])
    second = page(dir, "second.mxl", [{"Tenore", [:e4]}])

    {xml, bars, parts} = Audiveris.merge([first, second])
    Audiveris.write_mxl(Path.join(dir, "merged.mxl"), xml)
    {:ok, score} = Mx.Score.read(Path.join(dir, "merged.mxl"))

    assert bars == [2, 1]
    assert parts == [2, 1]
    assert Enum.map(score.parts, & &1.name) == ["Tenore", "Basso"]
    assert Enum.map(score.parts, &length(&1.bars)) == [3, 3]

    assert Enum.map(score.parts, &Enum.map(&1.bars, fn bar -> bar.number end)) == [
             [1, 2, 3],
             [1, 2, 3]
           ]

    assert heads(hd(score.parts)) == ["c4", "d4", "e4"]
  end

  defp heads(part) do
    for bar <- part.bars, voice <- bar.voices, group <- voice, note <- group.notes, do: note.name
  end

  defp page(dir, name, parts) do
    list =
      parts
      |> Enum.with_index(1)
      |> Enum.map_join(fn {{part, _notes}, index} ->
        escaped = String.replace(part, "'", "&apos;")
        ~s(<score-part id="P#{index}"><part-name>#{escaped}</part-name></score-part>)
      end)

    body =
      parts
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {{_part, notes}, index} ->
        measures =
          notes
          |> Enum.with_index(1)
          |> Enum.map_join(fn {note, number} -> measure(note, number) end)

        ~s(<part id="P#{index}">#{measures}</part>)
      end)

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0"><part-list>#{list}</part-list>
    #{body}
    </score-partwise>
    """

    path = Path.join(dir, name)
    Audiveris.write_mxl(path, xml)
    path
  end

  defp measure(note, number) do
    [_, step, octave] = Regex.run(~r/^([a-g])(\d)$/, Atom.to_string(note))
    step = String.upcase(step)

    """
    <measure number="#{number}"><attributes><divisions>1</divisions><time><beats>1</beats><beat-type>4</beat-type></time></attributes>
    <note><pitch><step>#{step}</step><octave>#{octave}</octave></pitch><duration>1</duration><type>quarter</type></note></measure>
    """
  end
end
