defmodule Mx.GuidesTest do
  use ExUnit.Case, async: true

  @declared "  def song, do: repeat(band())\n"

  test "every step of From a note to a song loads as a song" do
    steps =
      ~r/```elixir\n(.*?)```/s
      |> Regex.scan(File.read!("documentation/first_song.md"), capture: :all_but_first)
      |> List.flatten()

    module = Enum.find(steps, &(&1 =~ "defmodule"))
    assert module =~ @declared

    for {step, index} <- Enum.with_index(steps, 1) do
      whole? = step =~ "defmodule" or step =~ "import Mx"
      renamed = String.replace(module, "MaracatuDub", "MaracatuDubStep#{index}")
      source = if whole?, do: step, else: String.replace(renamed, @declared, step)

      assert {:ok, _song} = Mx.Song.load("first_song_step_#{index}.exs", source: source)
    end
  end
end
