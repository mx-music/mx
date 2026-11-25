defmodule Mx.InstrumentTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native
  alias Mx.Instrument.{Expr, Vocabulary}

  defp render(module, synth, options, seconds \\ 1.0) do
    {:ok, engine} = Native.start(false, false)
    :ok = Mx.Instrument.register(engine, module)

    :ok =
      Native.play(engine, [{0.0, Mxs.event({:note, nil, synth, nil, options, nil})}])

    {:ok, {left, _right}} = Native.render(engine, seconds)
    for <<x::float-32-native <- left>>, do: x
  end

  defp peak(samples), do: samples |> Enum.map(&abs/1) |> Enum.max()

  setup_all do
    source = """
    defmodule Mx.InstrumentTest.Picked do
      use Mx.Instrument
      @points [{0.01, 1}, {0.1, 0}]

      defsynth restarting(_hit), do: envelope(@points, every: 0.25) |> rings(seconds: 1)
      defsynth plain(_hit), do: envelope(@points) |> rings(seconds: 1)

      defsynth scaled(_hit) do
        envelope(sine(hz: 400), @points, every: 0.25) |> rings(seconds: 1)
      end

      attr :tremolo, :float, default: 0
      defsynth unpicked(hit), do: envelope(@points, every: 1 / hit.tremolo) |> rings(seconds: 1)
    end
    """

    [{module, _}] = Code.compile_string(source, "picked.exs")
    %{picked: module}
  end

  test "the marimba and the flute, as the guide sketches them, play through mxs" do
    marimba = render(Mx.Instruments.Marimba, :marimba, note: 60, vel: 0.8)
    flute = render(Mx.Instruments.Flute, :flute, note: 72, vel: 0.6, sustain: 0.5)
    assert peak(marimba) > 0.01
    assert peak(flute) > 0.01
    assert flute |> Enum.drop(round(0.9 * 48_000)) |> peak() < 1.0e-4
  end

  test "the tabla plays the clause its bol matches, at the bol's own pitch unless the note gives one" do
    na_stroke = render(Mx.Instruments.Tabla, :tabla, bol: :na)
    assert na_stroke == render(Mx.Instruments.Tabla, :tabla, [])
    assert peak(render(Mx.Instruments.Tabla, :tabla, bol: :ghe)) > 0.01
    refute render(Mx.Instruments.Tabla, :tabla, bol: :ghe) == na_stroke
    refute render(Mx.Instruments.Tabla, :tabla, bol: :na, note: 58) == na_stroke
  end

  test "a value outside an option's range plays held to it, and is reported once" do
    played = fn vel ->
      {:ok, engine} = Native.start(false, false)
      :ok = Mx.Instrument.register(engine, Mx.Instruments.Flute)
      note = Mxs.event({:note, nil, :flute, nil, [vel: vel], nil})
      :ok = Native.play(engine, [{0.0, note}, {0.5, note}])
      warnings = Native.warnings(engine)
      {:ok, {left, _right}} = Native.render(engine, 1.0)
      {left, warnings}
    end

    {too_hard, [warning]} = played.(1.5)
    assert warning =~ "vel"
    assert {^too_hard, []} = played.(1.0)
  end

  test "a harder stroke on the marimba is louder" do
    assert peak(render(Mx.Instruments.Marimba, :marimba, note: 60, vel: 1.0)) >
             peak(render(Mx.Instruments.Marimba, :marimba, note: 60, vel: 0.3))
  end

  test "the same marimba note, tap of noise and all, renders the same samples twice" do
    assert render(Mx.Instruments.Marimba, :marimba, note: 55) ==
             render(Mx.Instruments.Marimba, :marimba, note: 55)
  end

  test "each synth declares its options with their types, defaults and ranges" do
    [flute] = Mx.Instruments.Flute.__synths__()
    assert {:vel, :float, opts} = List.keyfind(flute.attrs, :vel, 0)
    assert opts[:default] == 0.6 and opts[:range] == {0, 1}
    assert {:sustain, :beats, sustain} = List.keyfind(flute.attrs, :sustain, 0)
    assert sustain[:default] == 0.5
  end

  test "a synth's documentation lists its options with their defaults and ranges" do
    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Mx.Instruments.Flute)
    {_, _, _, %{"en" => doc}, _} = List.keyfind(docs, {:function, :flute, 1}, 0)
    assert doc =~ "A flute note."
    assert doc =~ "- `note`, note, 52 by default: The pitch."
    assert doc =~ "- `vel`, float, 0.6 by default, from 0 to 1: How hard the note is blown."
    assert doc =~ "- `vibrato`, float, 0.25 by default, from 0 to 1"
    assert doc =~ "- `sustain`, beats, 0.5 by default"
    assert doc =~ "- `release`, beats, 0.2 by default"
  end

  test "an if on a note's option fails when the module compiles, naming the file, the line and select" do
    source = """
    defmodule Mx.InstrumentTest.Iffy do
      use Mx.Instrument
      attr :note, :note, default: 60
      attr :vel, :float, default: 0.6
      envelope_attrs()

      defsynth iffy(hit) do
        level = if hit.vel > 0.5, do: 1, else: 0.5
        sine(hz: hz(hit.note)) |> gain(level) |> note_envelope(hit)
      end
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "iffy.exs") end
    assert error.file =~ "iffy.exs"
    assert error.line == 8
    assert Exception.message(error) =~ "select(condition, then, else)"
  end

  test "mod gives the remainder from 0 up to its divisor, below 0 included, and records it on a value worked out from the note" do
    assert Vocabulary.mod(-0.25, 1) == 0.75
    assert Vocabulary.mod(2.5, 1) == 0.5
    time = Vocabulary.time()

    assert %Expr{op: :mod, args: [^time, 0.1]} =
             Vocabulary.mod(time, 0.1)
  end

  test "a synth with neither an envelope nor rings fails when its module compiles" do
    source = """
    defmodule Mx.InstrumentTest.Endless do
      use Mx.Instrument
      attr :note, :note, default: 60

      defsynth endless(hit) do
        sine(hz: hz(hit.note))
      end
    end
    """

    error = assert_raise CompileError, fn -> Code.compile_string(source, "endless.exs") end
    assert error.line == 5

    assert Exception.message(error) =~
             "endless ends with none of note_envelope, rings and figures"
  end

  test "data written in the module takes any Elixir, such as Enum.zip, and plays" do
    source = """
    defmodule Mx.InstrumentTest.Chime do
      use Mx.Instrument
      @ratios [1, 2.76, 5.4]
      @levels [0, -6, -12]
      attr :note, :note, default: 72

      defsynth chime(hit) do
        mix(for {ratio, level} <- Enum.zip(@ratios, @levels) do
          impulse() |> mode(hz: hz(hit.note) * ratio, level: db(level), fade: 1.5)
        end)
        |> gain(0.2)
        |> rings(seconds: 2)
      end
    end
    """

    [{module, _}] = Code.compile_string(source, "chime.exs")
    assert peak(render(module, :chime, note: 72)) > 0.01
  end

  test "a sum built in a loop twenty thousand terms deep registers and plays" do
    source = """
    defmodule Mx.InstrumentTest.Deep do
      use Mx.Instrument
      attr :note, :note, default: 60

      defsynth deep(hit) do
        level = Enum.reduce(1..20_000, 0, fn _, sum -> sum + hit.note / 1_200_000 end)
        sine(hz: hz(hit.note)) |> gain(level) |> rings(seconds: 0.5)
      end
    end
    """

    [{module, _}] = Code.compile_string(source, "deep.exs")
    assert peak(render(module, :deep, [note: 60], 0.2)) > 0.5
  end

  test "a synth saturates, clips and folds its sound, filters it through a ladder, and takes its offset away below hz" do
    source = """
    defmodule Mx.InstrumentTest.Grit do
      use Mx.Instrument

      attr :note, :note, default: 45
      defsynth saturated(hit), do: saw(hz: hz(hit.note)) |> saturate(drive: 24, level: 0.5) |> through()
      attr :note, :note, default: 45
      defsynth clipped(hit), do: saw(hz: hz(hit.note)) |> clip(drive: 12, level: 0.5) |> through()
      attr :note, :note, default: 45
      defsynth folded(hit), do: saw(hz: hz(hit.note)) |> fold(drive: 12, level: 0.5) |> through()

      defp through(sound) do
        sound |> ladder(hz: 800, resonance: 0.6) |> dc_block(hz: 20) |> rings(seconds: 1)
      end
    end
    """

    [{module, _}] = Code.compile_string(source, "grit.exs")

    for synth <- [:saturated, :clipped, :folded] do
      level = peak(render(module, synth, note: 45))
      assert level > 0.01 and level < 1, "#{synth} peaks at #{level}"
    end
  end

  describe "an envelope given every:" do
    test "starts over from its first point every that many seconds", %{picked: module} do
      samples = render(module, :restarting, [])
      rate = Mxs.render_rate()
      at = fn seconds -> Enum.at(samples, round(seconds * rate)) end
      assert at.(0.05) > 0
      assert_in_delta at.(0.30), at.(0.05), 1.0e-4
      assert at.(0.2) == 0
    end

    test "scales a sound that sounds the same each time it starts over", %{picked: module} do
      quarter = round(Mxs.render_rate() / 4)
      {first, rest} = Enum.split(render(module, :scaled, []), quarter)
      second = Enum.take(rest, quarter)
      assert peak(first) > 0.1
      assert first |> Enum.zip_with(second, &(&1 - &2)) |> peak() < 1.0e-3
    end

    test "worked out as 1 divided by a tremolo of 0 plays once, as without every:", %{
      picked: module
    } do
      assert render(module, :unpicked, []) == render(module, :plain, [])
    end
  end
end
