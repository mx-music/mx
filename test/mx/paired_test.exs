defmodule Mx.PairedTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs
  alias Mx.Engine.Mxs.Native

  defp render(module, synth, options, seconds) do
    {:ok, engine} = Native.start(false, false)
    if module, do: :ok = Mx.Instrument.register(engine, module)

    :ok =
      Native.play(engine, [{0.0, Mxs.event({:note, nil, synth, nil, options, nil})}])

    {:ok, {left, _right}} = Native.render(engine, seconds)
    for <<x::float-32-native <- left>>, do: x
  end

  defp rms(samples), do: :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / length(samples))

  # How far below the Rust form's level the difference between the two forms is, in decibels.
  defp apart(module, synth, options, seconds) do
    rust = render(nil, synth, options, seconds)
    elixir = render(module, synth, options, seconds)
    difference = Enum.zip_with(rust, elixir, &(&1 - &2))
    20 * :math.log10(max(rms(difference), 1.0e-12) / rms(rust))
  end

  for {module, synth, cases, seconds} <- Mx.Paired.Twins.all(), options <- cases do
    test "#{synth} at #{inspect(options)} renders the same in its defsynth and Rust forms" do
      apart = apart(unquote(module), unquote(synth), unquote(options), unquote(seconds))
      assert apart < -60, "#{apart} dB apart"
    end
  end

  test "the caxixi's shakes in a run render the same in its defsynth and Rust forms, each drawing its own peak" do
    shakes = fn module ->
      {:ok, engine} = Native.start(false, false)
      if module, do: :ok = Mx.Instrument.register(engine, module)

      events =
        for {at, vel} <- [{0.0, 0.6}, {0.3, 0.8}, {0.6, 0.5}, {0.9, 1.0}] do
          {at, Mxs.event({:note, nil, :caxixi, nil, [vel: vel], nil})}
        end

      :ok = Native.play(engine, events)
      {:ok, {left, _right}} = Native.render(engine, 3)
      for <<x::float-32-native <- left>>, do: x
    end

    rust = shakes.(nil)
    elixir = shakes.(Mx.Paired.Caxixi)
    difference = Enum.zip_with(rust, elixir, &(&1 - &2))
    apart = 20 * :math.log10(max(rms(difference), 1.0e-12) / rms(rust))
    assert apart < -60, "#{apart} dB apart"
  end

  test "the cello sliding from C3 to E-flat 3 renders the same in its defsynth and Rust forms" do
    slid = fn module, to ->
      {:ok, engine} = Native.start(false, false)
      if module, do: :ok = Mx.Instrument.register(engine, module)

      events = [
        {0.0, Mxs.event({:note, 1, :cello, nil, [note: 48, sustain: 2.5], nil})},
        {1.2, Mxs.event({:set, {:sounds, [1]}, note: to})}
      ]

      :ok = Native.play(engine, events)
      {:ok, {left, _right}} = Native.render(engine, 3)
      for <<x::float-32-native <- left>>, do: x
    end

    rust = slid.(nil, 51)
    elixir = slid.(Mx.Paired.Cello, 51)
    assert rust != slid.(nil, 48)
    difference = Enum.zip_with(rust, elixir, &(&1 - &2))
    apart = 20 * :math.log10(max(rms(difference), 1.0e-12) / rms(rust))
    assert apart < -60, "#{apart} dB apart"
  end

  test "the trumpet slurring from C5 to G5 renders the same in its defsynth and Rust forms" do
    slurred = fn module, to ->
      {:ok, engine} = Native.start(false, false)
      if module, do: :ok = Mx.Instrument.register(engine, module)

      events = [
        {0.0, Mxs.event({:note, 1, :trumpet, nil, [note: 72, sustain: 2.5], nil})},
        {1.2, Mxs.event({:set, {:sounds, [1]}, note: to})}
      ]

      :ok = Native.play(engine, events)
      {:ok, {left, _right}} = Native.render(engine, 3)
      for <<x::float-32-native <- left>>, do: x
    end

    rust = slurred.(nil, 79)
    elixir = slurred.(Mx.Paired.Trumpet, 79)
    assert rust != slurred.(nil, 72)
    difference = Enum.zip_with(rust, elixir, &(&1 - &2))
    apart = 20 * :math.log10(max(rms(difference), 1.0e-12) / rms(rust))
    assert apart < -60, "#{apart} dB apart"
  end
end
