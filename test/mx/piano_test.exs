defmodule Mx.PianoTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs
  alias Mx.Measure.Hits
  alias Mx.Piano

  test "the parts of middle C list its harmonics from the first, at 261.6 Hz" do
    {:ok, parts} = Piano.parts(note: 60, vel: 0.6)
    [first | _] = parts.harmonics

    assert first.number == 1
    assert_in_delta first.hz, 261.63, 0.5

    for harmonic <- parts.harmonics do
      assert harmonic.hz > 0 and harmonic.level <= 0 and harmonic.fade > 0
    end
  end

  test "a note below C2 has more harmonics than middle C" do
    {:ok, low} = Piano.parts(note: 24)
    {:ok, middle} = Piano.parts(note: 60)

    assert length(low.harmonics) > length(middle.harmonics)
  end

  test "a harder strike gives the tenth harmonic more against the first" do
    tenth = fn vel ->
      {:ok, parts} = Piano.parts(note: 60, vel: vel)
      Enum.find(parts.harmonics, &(&1.number == 10)).level
    end

    assert tenth.(1) > tenth.(0.3)
  end

  test "the pedal lets the first harmonic fade longer" do
    fade = fn pedal ->
      {:ok, %{harmonics: [first | _]}} = Piano.parts(note: 60, pedal: pedal)
      first.fade
    end

    assert fade.(1) > fade.(0)
  end

  test "the thump, the knock and the partners are given beside the harmonics" do
    {:ok, parts} = Piano.parts(note: 60)

    assert parts.thump.below_hz > 0 and parts.thump.seconds > 0
    resonances = Enum.map(parts.knock.resonances, &Float.round(&1, 1))
    assert resonances == [64.1, 98.5, 136.6, 179.0, 337.6, 403.0, 476.0]
    assert Enum.any?(parts.partners, &(&1.kind == :twin))
    assert {:ok, %{knock: nil}} = Piano.parts(note: 60, knock: 0)
  end

  test "the same note, vel and pedal always give the same parts" do
    assert Piano.parts(note: 60, vel: 0.6, pedal: 0.5) ==
             Piano.parts(note: 60, vel: 0.6, pedal: 0.5)
  end

  test "a note outside the piano's keys is refused, naming them" do
    assert Piano.parts(note: 20) ==
             {:error, "the piano's keys are from A0 to C8, MIDI notes 21 to 108"}

    assert {:error, _} = Piano.parts(note: 109)
  end

  test "a value out of range is held, with a warning, and an unknown option refused" do
    assert {:ok, %{warnings: ["piano's option vel was held to its range, 0.05 to 1"]}} =
             Piano.parts(note: 60, vel: 2)

    assert Piano.parts(note: 60, brightness: 1) == {:error, "piano has no option brightness"}
  end

  @tag :engine
  test "a rendered note shows its first 8 harmonics at the frequencies and fades its parts give" do
    {:ok, parts} = Piano.parts(note: 60, vel: 0.6, knock: 0)
    rate = Mxs.render_rate()
    sound = Mxs.render_note(:piano, [note: 60, vel: 0.6, knock: 0, sustain: 8], 5, nil, [])
    rendered = Hits.hit(sound, rate, 60, partials: 12)

    # A partner rings a hair from its harmonic, so their fade is measured from the parts summed.
    built = Hits.hit(built(parts, rate, 5), rate, 60, partials: 12)

    for harmonic <- Enum.take(parts.harmonics, 8) do
      heard = Enum.min_by(rendered.partials, &abs(&1.hz - harmonic.hz))
      given = Enum.min_by(built.partials, &abs(&1.hz - harmonic.hz))

      assert abs(heard.hz - harmonic.hz) < 1,
             "harmonic #{harmonic.number} is at #{heard.hz} Hz, not #{harmonic.hz} Hz"

      assert abs(heard.ring / given.ring - 1) < 0.1,
             "harmonic #{harmonic.number} fades in #{heard.ring} s, not #{given.ring} s"
    end
  end

  defp built(parts, rate, seconds) do
    rings = parts.harmonics ++ parts.partners

    for sample <- 0..(seconds * rate - 1) do
      time = sample / rate

      Enum.reduce(rings, 0.0, fn ring, sum ->
        size = 10 ** (ring.level / 20) * 10 ** (-3 * time / ring.fade)
        sum + size * :math.sin(2 * :math.pi() * ring.hz * time)
      end)
    end
  end
end
