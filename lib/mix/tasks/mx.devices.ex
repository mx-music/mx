defmodule Mix.Tasks.Mx.Devices do
  @shortdoc "Lists the sound devices mx can play through and read from"

  @moduledoc """
  Lists each output and input device by the name `mix mx.play --output` and `--input` take, with
  the channel counts, sample rates and buffer sizes it supports, and marks the defaults.

      mx devices
  """

  use Mix.Task

  alias Mx.Engine.Mxs.Native

  @impl true
  def run([]) do
    case Native.devices() do
      {:ok, devices} ->
        {outputs, inputs} = Enum.split_with(devices, &elem(&1, 1))
        list("Outputs", outputs)
        list("Inputs", inputs)

      {:error, message} ->
        Mx.Command.fail(message)
    end
  end

  defp list(heading, devices) do
    IO.puts(heading)
    Enum.each(devices, &IO.puts("  " <> describe(&1)))
  end

  defp describe({name, _output, default, channels, rates, buffers}) do
    mark = if default, do: ", the default", else: ""
    count = Enum.join(channels, " or ")
    noun = if channels == [1], do: "channel", else: "channels"
    hz = Enum.map_join(rates, ", ", &span/1)
    frames = if buffers, do: ", buffers of #{span(buffers)} frames", else: ""
    "#{name}#{mark}: #{count} #{noun} at #{hz} Hz#{frames}"
  end

  defp span({low, low}), do: "#{low}"
  defp span({low, high}), do: "#{low} to #{high}"
end
