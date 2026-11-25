defmodule Mx.CompressorTest do
  # A render runs the one engine and the one render clock, so tests that render share a group.
  use ExUnit.Case, async: true, group: :engine

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @rate 48_000

  defp write(ctx, song) do
    path = Path.join(ctx.tmp_dir, "song.exs")
    File.write!(path, "import Mx\n" <> song <> "\n")
    path
  end

  defp load(ctx, song), do: Mx.Song.load(write(ctx, song))

  # Both sides of a render of a song.
  defp render(ctx, song) do
    path = write(ctx, song)
    out = Path.join(ctx.tmp_dir, "song.wav")
    File.rm(out)
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, ring_out: false) end)
    {:ok, _format, data} = Mx.Audio.raw(out)
    frames = for <<left::little-float-32, right::little-float-32 <- data>>, do: {left, right}
    Enum.unzip(frames)
  end

  defp between(samples, from, to) do
    Enum.slice(samples, round(from * @rate)..(round(to * @rate) - 1))
  end

  defp peak_db(samples), do: 20 * :math.log10(samples |> Enum.map(&abs/1) |> Enum.max())

  # A sine for 2 seconds whose amp is set so that it peaks at `db`, through the effects given.
  defp tone(ctx, db, fx, pan \\ 0) do
    {dry, _} =
      render(
        ctx,
        "song(tempo: 120, music: part(:x, note(:a4, 4, amp: 1, pan: #{pan}), synth: :tri))"
      )

    amp = :math.pow(10, (db - peak_db(between(dry, 1, 1.5))) / 20)
    "part(:x, note(:a4, 4, amp: #{amp}, pan: #{pan}), synth: :tri, fx: #{fx})"
  end

  @tag :engine
  test "a tone over the threshold comes out lower by the ratio, one under it as it was, and makeup raises it",
       ctx do
    squeezed = "[compressor: [threshold: -18, ratio: 4]]"
    {left, _} = render(ctx, "song(tempo: 120, music: #{tone(ctx, -6, squeezed)})")
    assert_in_delta peak_db(between(left, 1, 1.5)), -15, 0.5

    {left, _} = render(ctx, "song(tempo: 120, music: #{tone(ctx, -30, squeezed)})")
    assert_in_delta peak_db(between(left, 1, 1.5)), -30, 0.2

    raised = "[compressor: [threshold: -18, ratio: 4, makeup: 6]]"
    {left, _} = render(ctx, "song(tempo: 120, music: #{tone(ctx, -6, raised)})")
    assert_in_delta peak_db(between(left, 1, 1.5)), -9, 0.5
  end

  @tag :engine
  test "a loud tone on the left lowers a quiet tone on the right by as much as the left", ctx do
    parts = fn fx ->
      music =
        "together([part(:loud, note(:a4, 4, amp: 1, pan: -1), synth: :tri), part(:quiet, note(:e5, 4, amp: 0.02, pan: 1), synth: :tri)])"

      "song(tempo: 120, #{fx}music: #{music})"
    end

    {dry_left, dry_right} = render(ctx, parts.(""))
    {left, right} = render(ctx, parts.("fx: [compressor: [threshold: -24, ratio: 4]], "))
    down = fn wet, dry -> peak_db(between(wet, 1, 1.5)) - peak_db(between(dry, 1, 1.5)) end
    assert down.(left, dry_left) < -6
    assert_in_delta down.(left, dry_left), down.(right, dry_right), 0.2
  end

  @tag :engine
  test "a pad keyed by the kick drops under each kick and comes back, and the kick sounds as it did",
       ctx do
    kick = "part(:kick, seq(for _ <- 1..4, do: seq([note(36, 0), rest(1)])), synth: :kick)"
    pad = fn fx -> "part(:pad, note(:a4, 4, amp: 0.2), synth: :tri#{fx})" end
    keyed = ", fx: [compressor: [key: :kick, threshold: -24, ratio: 8]]"
    song = fn parts -> "song(tempo: 120, music: together([#{Enum.join(parts, ", ")}]))" end

    {kick_alone, _} = render(ctx, song.([kick]))
    {pad_alone, _} = render(ctx, song.([pad.("")]))
    {both, _} = render(ctx, song.([kick, pad.(keyed)]))
    {silent_pad, _} = render(ctx, song.([kick, "part(:pad, rest(4), synth: :tri#{keyed})"]))
    ducked = Enum.zip_with(both, kick_alone, &(&1 - &2))
    level = fn samples, at -> peak_db(between(samples, at, at + 0.01)) end

    for beat <- 1..3 do
      at = beat * 0.5
      assert_in_delta level.(ducked, at - 0.03), level.(pad_alone, at - 0.03), 1
      assert level.(ducked, at + 0.02) < level.(pad_alone, at + 0.02) - 6
      assert_in_delta level.(ducked, at + 0.4), level.(pad_alone, at + 0.4), 1
    end

    assert silent_pad == kick_alone
  end

  test "a compressor's key that names no part or bus is refused, naming it", ctx do
    path = Path.join(ctx.tmp_dir, "song.exs")
    pad = "part(:pad, note(:a4, 4), synth: :tri, fx: [compressor: [key: :cowbell]])"

    assert load(ctx, "song(music: #{pad})") ==
             {:error,
              "#{path}:2: part pad: the compressor's key cowbell names no part or bus of the song"}

    kick = "part(:kick, note(36, 1), synth: :kick)"
    keyed = "part(:pad, note(:a4, 4), synth: :tri, fx: [compressor: [key: :kick]])"
    assert {:ok, song} = load(ctx, "song(music: together([#{kick}, #{keyed}]))")
    assert [compressor: [key: :kick]] = Enum.find(song.loops, &(&1.name == :pad)).fx

    assert {:ok, _song} =
             load(
               ctx,
               "song(buses: [room: [reverb: []]], music: part(:pad, note(:a4, 4), synth: :tri, fx: [compressor: [key: :room]]))"
             )

    assert load(
             ctx,
             "song(music: part(:pad, note(:a4, 4), synth: :tri, fx: [compressor: [key: 3]]))"
           ) ==
             {:error,
              "#{path}:2: part pad: effect compressor takes key: as the name of a part or a bus, not 3"}

    assert load(
             ctx,
             "song(music: part(:pad, note(:a4, 4), synth: :tri, fx: [reverb: [key: :kick]]))"
           ) ==
             {:error, "#{path}:2: part pad: effect reverb has no option key"}
  end

  test "the options the compressor no longer has are refused as any it does not have", ctx do
    path = Path.join(ctx.tmp_dir, "song.exs")
    pad = fn option -> "part(:pad, note(:a4, 4), synth: :tri, fx: [compressor: [#{option}]])" end

    for option <- [
          "slope_above: 0.5",
          "slope_below: 1",
          "clamp_time: 0.01",
          "relax_time: 0.01",
          "no_such: 1"
        ] do
      [name, _value] = String.split(option, ": ")

      assert load(ctx, "song(music: #{pad.(option)})") ==
               {:error, "#{path}:2: part pad: effect compressor has no option #{name}"}
    end

    slid =
      "threshold: -20, threshold_slide: 1, ratio_slide: 1, makeup_slide: 1, clamp_ms_slide: 1, relax_ms_slide: 1"

    assert {:ok, _song} = load(ctx, "song(music: #{pad.(slid)})")
  end
end
