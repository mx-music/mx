defmodule Mx.Examples.TimelineTest do
  # Each example plays every step it played before it moved to the new notation, at the same beat
  # with the same options.
  # It points mx at the whole sample pack, which other tests must not see, so it runs alone.
  use ExUnit.Case, async: false

  setup_all do
    dir = Application.get_env(:mx, :samples_dir)
    Application.put_env(:mx, :samples_dir, Mx.Samples.default_dir())
    on_exit(fn -> Application.put_env(:mx, :samples_dir, dir) end)
  end

  for timeline <- Enum.sort(Path.wildcard("test/examples/timelines/**/*.timeline")) do
    song =
      timeline
      |> Path.relative_to("test/examples/timelines")
      |> String.replace_suffix(".timeline", ".exs")

    @timeline timeline
    @song Path.join("examples", song)

    if File.read!(@song) =~ "{:sonic_pi," do
      @tag :sonic_pi
    end

    test "#{song} plays as it did" do
      {expected, _} = @timeline |> File.read!() |> Code.eval_string()
      spans = Map.new(expected, fn {name, {_events, beats}} -> {name, beats} end)
      played = Mx.Timeline.by_beats(@song, spans)

      assert Enum.sort(Map.keys(played)) == Enum.sort(Map.keys(expected))

      for {name, {events, _beats}} <- expected do
        {played_events, _} = played[name]
        assert played_events == events, "#{name} plays other steps"
      end
    end
  end
end
