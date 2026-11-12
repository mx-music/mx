defmodule Mx.SampleFormatsTest do
  use ExUnit.Case, async: true

  alias Mx.Engine.Mxs.Native
  alias Mx.Samples

  # The left channel of a sample file played at its own rate, from an offline engine.
  defp played(path, seconds) do
    {:ok, engine} = Native.start(false, false)
    {:ok, {sample, _channels}} = Native.load_sample(engine, path)

    :ok =
      Native.play(engine, [
        {0.0, Mx.Engine.Mxs.event({:sample, nil, %{sample: sample, channels: 1}, [], nil})}
      ])

    {:ok, {left, _right}} = Native.render(engine, seconds)
    for <<x::float-32-native <- left>>, do: x
  end

  @tag :tmp_dir
  test "a file that is not a sound is refused whatever its name, saying why", %{tmp_dir: dir} do
    path = Path.join(dir, "kick.wav")
    File.write!(path, "not a sound\n")

    assert Samples.path(path) ==
             {:error, "sample file #{path} cannot play: it is not a FLAC, WAV or AIFF file"}
  end

  # Versilian Studios' Versilian Community Sample Library, from https://github.com/sgossner/VCSL, in the folder MX_VCSL names.
  describe "VCSL" do
    @describetag :vcsl
    @describetag timeout: 900_000

    setup do
      {:ok, dir: System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")}
    end

    test "every one of its WAV files loads, those with a 20-byte format header among them", %{
      dir: dir
    } do
      files = Path.wildcard(Path.join(dir, "**/*.wav"))
      assert length(files) == 4231
      {:ok, engine} = Native.start(false, false)

      refused =
        for file <- files, not match?({:ok, _}, Native.load_sample(engine, file)), do: file

      assert refused == []
    end

    test "the darbuka's fifth hit plays", %{dir: dir} do
      path =
        Path.join(dir, "Membranophones/Struck Membranophones/Darbuka/Darbuka_5_hit_vl2_rr2.wav")

      assert {:ok, _} = Samples.path(path)
      assert Enum.max(Enum.map(played(path, 1), &abs/1)) > 0.01
    end
  end

  # NASA's recording of the Apollo 11 landing, an 8-bit mono AIFF file, from https://nssdc.gsfc.nasa.gov/planetary/lunar/a11landing.aiff, in the folder MX_NASA names.
  describe "AIFF" do
    @describetag :nasa

    setup do
      {:ok,
       dir: System.get_env("MX_NASA") || flunk("set MX_NASA to the folder of a11landing.aiff")}
    end

    test "the Apollo 11 landing plays at its own pitch for its 3.59 seconds", %{dir: dir} do
      path = Path.join(dir, "a11landing.aiff")
      assert {:ok, _} = Samples.path(path)
      sound = played(path, 4)
      last = Enum.find_index(Enum.reverse(sound), &(&1 != 0.0))
      assert_in_delta (length(sound) - last) / 48_000, 3.59, 0.01
    end
  end
end
