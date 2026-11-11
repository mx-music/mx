defmodule Mx.PairedTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs.Native

  defp render(module, synth, options, seconds) do
    {:ok, engine} = Native.start(false, false)
    if module, do: :ok = Mx.Instrument.register(engine, module)

    :ok =
      Native.play(engine, [{0.0, Mx.Engine.Mxs.event({:note, nil, synth, nil, options, nil})}])

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

  for vel <- [0.3, 1] do
    test "the marimba's note 60 at vel #{vel} renders the same in its defsynth and Rust forms" do
      apart = apart(Mx.Paired.Marimba, :marimba, [note: 60, vel: unquote(vel)], 3)
      assert apart < -60, "#{apart} dB apart"
    end
  end
end
