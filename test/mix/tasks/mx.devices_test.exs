defmodule Mix.Tasks.Mx.DevicesTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @tag :engine
  test "lists each output and input by the name the options take, with its channels, rates and buffers, marking the defaults" do
    {:ok, devices} = Mx.Engine.Mxs.Native.devices()
    said = capture_io(fn -> Mix.Tasks.Mx.Devices.run([]) end)
    [outputs, inputs] = String.split(said, "Inputs\n")
    assert outputs =~ ~r/^Outputs\n/

    for {name, output?, default?, channels, _rates, _buffers} <- devices do
      listed = if output?, do: outputs, else: inputs
      mark = if default?, do: ", the default", else: ""
      count = Enum.join(channels, " or ")

      assert listed =~
               ~r/^  #{Regex.escape(name)}#{mark}: #{count} channels? at [0-9, to]+ Hz(, buffers of \d+ to \d+ frames)?$/m
    end
  end
end
