defmodule Mx.AudioTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "writes a mono WAV file that reads back the same", %{tmp_dir: dir} do
    path = Path.join(dir, "ramp.wav")
    samples = for index <- 0..999, do: index / 1000 - 0.5
    Mx.Audio.write(path, samples, 44_100)

    assert {:ok, %{rate: 44_100, samples: read}} = Mx.Audio.read(path)
    assert length(read) == 1000

    for {written, back} <- Enum.zip(samples, read) do
      assert_in_delta written, back, 1.0e-6
    end
  end
end
