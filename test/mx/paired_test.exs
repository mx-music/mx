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

  # The median of five renders' milliseconds per second of sound, building the note included.
  defp timed(module, synth, options, seconds) do
    for _ <- 1..5 do
      {:ok, engine} = Native.start(false, false)
      if module, do: :ok = Mx.Instrument.register(engine, module)
      event = Mx.Engine.Mxs.event({:note, nil, synth, nil, options, nil})

      {micros, {:ok, _}} =
        :timer.tc(fn ->
          :ok = Native.play(engine, [{0.0, event}])
          Native.render(engine, seconds)
        end)

      micros / 1000 / seconds
    end
    |> Enum.sort()
    |> Enum.at(2)
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

  @tag :bench
  test "prints each paired instrument's render time per second of sound in both forms" do
    for {module, synth, options, seconds} <- [
          {Mx.Paired.Marimba, :marimba, [note: 60, vel: 1], 3}
        ] do
      rust = Float.round(timed(nil, synth, options, seconds), 2)
      elixir = Float.round(timed(module, synth, options, seconds), 2)
      IO.puts("#{synth}: #{rust} ms in Rust, #{elixir} ms in defsynth, per second of sound")
    end
  end
end
