defmodule Mx.SampledTest do
  # The note-length test renders, and a render drives the application's own clock and engine.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mx.{Pass, Recording, Sampled, Song}

  @moduletag :tmp_dir

  # A mono 16-bit WAV at 48 kHz holding `seconds` of a level of 0.5.
  defp wav(path, seconds) do
    frames = round(seconds * 48_000)
    data = :binary.copy(<<16_384::little-signed-16>>, frames)
    size = byte_size(data)

    File.write!(
      path,
      "RIFF" <>
        <<36 + size::little-32>> <>
        "WAVEfmt " <>
        <<16::little-32, 1::little-16, 1::little-16, 48_000::little-32, 96_000::little-32,
          2::little-16, 16::little-16>> <> "data" <> <<size::little-32>> <> data
    )

    path
  end

  defp folder(dir, name, files, seconds \\ 0.5) do
    folder = Path.join(dir, name)
    File.mkdir_p!(folder)
    for file <- files, do: wav(Path.join(folder, file), seconds)
    folder
  end

  defp load(dir, body) do
    path = Path.join(dir, "song.exs")
    File.write!(path, "import Mx\n" <> body)
    Song.load(path)
  end

  test "a sampled instrument of a list of files is named by the folder they share, with their collection, or by its first file and the count of the others" do
    kick =
      for take <- 1..2,
          do: {{:virtuosity_drums, "Samples/kickmic/kick/kickmic_kick_vl1_rr#{take}.flac"}, []}

    assert to_string(Sampled.new(kick)) ==
             "sampled instrument Samples/kickmic/kick of virtuosity_drums"

    assert to_string(Sampled.new([{"keys/c4.wav", note: 60}, {"keys/soft/c4.wav", note: 60}])) ==
             "sampled instrument keys"

    apart = [{"kick.wav", note: 36}, {"snare.wav", note: 38}, {"hat.wav", note: 42}]
    assert to_string(Sampled.new(apart)) == "sampled instrument kick.wav and 2 others"

    mixed = [{{:vcsl, "Drums/kick.wav"}, note: 36}, {"Drums/snare.wav", note: 38}]
    assert to_string(Sampled.new(mixed)) == "sampled instrument kick.wav and 1 other"

    folder = {:vcsl, "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"}

    assert to_string(Sampled.new(folder)) ==
             "sampled instrument Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B of vcsl"
  end

  # Each sample a part plays in a pass, as its file name and rate rounded to four places.
  defp played(song, name, pass \\ 0) do
    loop = Enum.find(song.loops, &(&1.name == name))
    {:ok, %{events: events}} = Pass.events(loop, pass)

    for {_beat, {:sample, path, _}, opts} <- events,
        do: {Path.basename(path), Float.round(opts[:rate], 4)}
  end

  test "reads the note, strength and take from VCSL's file names" do
    assert Sampled.describe("MBira4_pluck_Main_C#3_2_50_100_rr5.wav") == %{note: 49, take: 5}
    assert Sampled.describe("BDrumNew_hit_v5_rr1_Sum.wav") == %{strength: 5, take: 1}
    assert Sampled.describe("Shaker_vl3_rr2.wav") == %{strength: 3, take: 2}
    assert Sampled.describe("Organ Bb2 sustain.wav") == %{note: 46}
    assert Sampled.describe("kick.wav") == %{}
  end

  test "a note plays the nearest key, the lower on a tie, at the rate of its pitch, cents included",
       %{
         tmp_dir: dir
       } do
    keys = folder(dir, "keys", ["Keys_C4_rr1.wav", "Keys_D4_rr1.wav", "Keys_A4_rr1.wav"])

    {:ok, song} =
      load(dir, """
      song(music: part(:keys, seq([note(:c4, 1), note(:cs4, 1), note(:d4, 1), note(:g4, 1), note(:gs4, 1), note(62 + cents(30), 1)]), synth: sampled(#{inspect(keys)})))
      """)

    assert played(song, :keys) == [
             {"Keys_C4_rr1.wav", 1.0},
             {"Keys_C4_rr1.wav", 1.0595},
             {"Keys_D4_rr1.wav", 1.0},
             {"Keys_A4_rr1.wav", 0.8909},
             {"Keys_A4_rr1.wav", 0.9439},
             {"Keys_D4_rr1.wav", 1.0175}
           ]
  end

  test "vel picks a strength spread evenly from softest to hardest, and scales the level", %{
    tmp_dir: dir
  } do
    drum = folder(dir, "drum", ["Drum_v2_rr1.wav", "Drum_v5_rr1.wav", "Drum_v9_rr1.wav"])

    {:ok, song} =
      load(dir, """
      song(music: part(:drum, seq([hit(vel: 0), rest(1), hit(vel: 0.3), rest(1), hit(vel: 0.5), rest(1), hit(vel: 0.7), rest(1), hit(vel: 1, amp: 0.5), rest(1)]), synth: sampled(#{inspect(drum)})))
      """)

    assert Enum.map(played(song, :drum), &elem(&1, 0)) ==
             ~w(Drum_v2_rr1.wav Drum_v2_rr1.wav Drum_v5_rr1.wav Drum_v9_rr1.wav Drum_v9_rr1.wav)

    loop = hd(song.loops)
    {:ok, %{events: events}} = Pass.events(loop, 0)
    amps = for {_, {:sample, _, _}, opts} <- events, do: opts[:amp]
    assert amps == [0, 0.3, 0.5, 0.7, 0.5]
  end

  test "repeated notes play their key's takes in turn, carrying on from pass to pass", %{
    tmp_dir: dir
  } do
    drum = folder(dir, "drum", ["Drum_v1_rr2.wav", "Drum_v1_rr1.wav", "Drum_v1_rr3.wav"])

    {:ok, song} =
      load(dir, """
      song(music: together([
        part(:four, seq([hit(), rest(1), hit(), rest(1), hit(), rest(1), hit(), rest(1)]), synth: sampled(#{inspect(drum)})),
        part(:one, loop(1, fn _, _ -> seq([hit(), rest(1)]) end), synth: sampled(#{inspect(drum)}))
      ]))
      """)

    assert Enum.map(played(song, :four), &elem(&1, 0)) ==
             ~w(Drum_v1_rr1.wav Drum_v1_rr2.wav Drum_v1_rr3.wav Drum_v1_rr1.wav)

    assert Enum.map(0..3, &(song |> played(:one, &1) |> hd() |> elem(0))) ==
             ~w(Drum_v1_rr1.wav Drum_v1_rr2.wav Drum_v1_rr3.wav Drum_v1_rr1.wav)

    assert played(song, :four) == played(song, :four)
  end

  test "a list of files gives each its note, strength and take", %{tmp_dir: dir} do
    low = wav(Path.join(dir, "low.wav"), 0.5)
    high = wav(Path.join(dir, "high.wav"), 0.5)

    {:ok, song} =
      load(dir, """
      song(music: part(:bass, seq(c2: 1, c3: 1), synth: sampled([{#{inspect(low)}, note: :c2}, {#{inspect(high)}, note: 48}])))
      """)

    assert played(song, :bass) == [{"low.wav", 1.0}, {"high.wav", 1.0}]
  end

  test "a chord plays each note's key, strummed", %{tmp_dir: dir} do
    keys = folder(dir, "keys", ["K_E3.wav", "K_G#3.wav", "K_B3.wav"])

    {:ok, song} =
      load(dir, """
      song(music: part(:keys, note([:e3, :gs3, :b3], 1, strum: 0.05), synth: sampled(#{inspect(keys)})))
      """)

    loop = hd(song.loops)
    {:ok, %{events: events}} = Pass.events(loop, 0)

    played = for {beat, {:sample, path, _}, _} <- events, do: {beat, Path.basename(path)}

    assert played == [
             {0, "K_E3.wav"},
             {0.05, "K_G#3.wav"},
             {0.1, "K_B3.wav"}
           ]
  end

  test "a note lasts its length, then fades over its release", %{tmp_dir: dir} do
    keys = folder(dir, "keys", ["K_C4.wav"], 3)
    path = Path.join(dir, "long.exs")

    File.write!(path, """
    import Mx
    song(tempo: 120, music: part(:keys, note(:c4, 2, release: 0.5), synth: sampled(#{inspect(keys)})))
    """)

    out = Path.join(dir, "long.wav")
    capture_io(fn -> assert :ok = Mx.Render.render(path, out, []) end)
    level = levels(out)

    assert Enum.at(level, 95) > -10
    assert Enum.at(level, 112) < Enum.at(level, 95) - 3
    assert Enum.at(level, 112) > -60
    assert level |> Enum.drop(126) |> Enum.all?(&(&1 == :silent))
    assert %{peak: _} = Recording.level(out)
  end

  test "a folder with no notes, strengths or takes in its names is refused, naming the part and the folder",
       %{tmp_dir: dir} do
    plain = folder(dir, "plain", ["kick.wav", "snare.wav"])

    assert {:error, message} =
             load(dir, "song(music: part(:drums, hit(), synth: sampled(#{inspect(plain)})))\n")

    assert message =~
             "part drums: folder #{plain} has no files whose names carry a note, a strength or a take"
  end

  test "a listed file that does not exist is refused, naming the part and the file", %{
    tmp_dir: dir
  } do
    missing = Path.join(dir, "missing.wav")

    assert {:error, message} =
             load(
               dir,
               "song(music: part(:bass, note(:c2, 1), synth: sampled([{#{inspect(missing)}, note: :c2}])))\n"
             )

    assert message =~ "part bass: sampled file #{missing} does not exist"
  end

  test "an option samples work out themselves is refused", %{tmp_dir: dir} do
    keys = folder(dir, "keys", ["K_C4.wav"])

    assert {:error, message} =
             load(
               dir,
               "song(music: part(:keys, note(:c4, 1, rate: 2), synth: sampled(#{inspect(keys)})))\n"
             )

    assert message =~ "sampled instrument #{keys} has no option rate"
  end

  test "a hit on an instrument whose files all carry notes is refused", %{tmp_dir: dir} do
    keys = folder(dir, "keys", ["K_C4.wav"])

    assert {:error, message} =
             load(dir, "song(music: part(:keys, hit(), synth: sampled(#{inspect(keys)})))\n")

    assert message =~ "has a note in every file's name, so each note needs a pitch"
  end

  test "mix mx.print shows which file each note plays and at what rate", %{tmp_dir: dir} do
    keys = folder(dir, "keys", ["K_C4.wav"])
    path = Path.join(dir, "print.exs")

    File.write!(path, """
    import Mx
    song(music: part(:keys, seq(d4: 1), synth: sampled(#{inspect(keys)})))
    """)

    output = capture_io(fn -> Mix.Tasks.Mx.Print.run([path]) end)
    file = Path.join(keys, "K_C4.wav")
    assert output =~ "beat 0  sample #{file} amp: 1, sustain: 1, rate: 1.122462048309373"
  end

  test "the notation guide describes sampled instruments" do
    assert File.read!("documentation/notation.md") =~ "`sampled(folder)` makes an instrument"
  end

  # The peak level of each hundredth of a second of a WAV file in dB, or :silent.
  defp levels(path) do
    wav = File.read!(path)
    {at, _} = :binary.match(wav, "data")
    data = binary_part(wav, at + 8, byte_size(wav) - at - 8)
    samples = for <<x::little-float-32 <- data>>, do: abs(x)

    for frames <- Enum.chunk_every(samples, 960) do
      case Enum.max(frames) do
        peak when peak < 1.0e-6 -> :silent
        peak -> 20 * :math.log10(peak)
      end
    end
  end

  # Versilian Studios' Versilian Community Sample Library, from https://github.com/sgossner/VCSL,
  # in the folder MX_VCSL names.
  describe "VCSL" do
    @describetag :vcsl

    setup do
      {:ok, vcsl: System.get_env("MX_VCSL") || flunk("set MX_VCSL to the folder of the VCSL")}
    end

    test "the mbira plays E4 from its E4 file, F4 and cents from it faster, and a strummed chord from its keys",
         %{tmp_dir: dir, vcsl: vcsl} do
      mbira =
        Path.join(
          vcsl,
          "Idiophones/Plucked Idiophones/Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B"
        )

      {:ok, song} =
        load(dir, """
        song(music: part(:mbira, seq([note(:e4, 1), note(:f4, 1), note(64 + cents(30), 1)]), synth: sampled(#{inspect(mbira)})))
        """)

      e4 = "MBira4_pluck_Main_E4_19_50_100_rr2.wav"
      assert played(song, :mbira) == [{e4, 1.0}, {e4, 1.0595}, {e4, 1.0175}]
    end

    test "the bass drum plays strength 2 at vel 0 and 7 at vel 1, alternating its takes", %{
      tmp_dir: dir,
      vcsl: vcsl
    } do
      drum = Path.join(vcsl, "Membranophones/Struck Membranophones/Bass Drum 1")

      {:ok, song} =
        load(dir, """
        song(music: part(:drum, seq([hit(vel: 0), rest(1), hit(vel: 1), rest(1), hit(vel: 1), rest(1), hit(vel: 1), rest(1), hit(vel: 1), rest(1)]), synth: sampled(#{inspect(drum)})))
        """)

      assert Enum.map(played(song, :drum), &elem(&1, 0)) == [
               "BDrumNew_hit_v2_rr1_Sum.wav",
               "BDrumNew_hit_v7_rr1_Sum.wav",
               "BDrumNew_hit_v7_rr2_Sum.wav",
               "BDrumNew_hit_v7_rr1_Sum.wav",
               "BDrumNew_hit_v7_rr2_Sum.wav"
             ]
    end
  end
end
