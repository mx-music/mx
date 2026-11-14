defmodule Mix.Tasks.Mx.PrintTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mx.Print

  test "prints each note of a pass with its beat" do
    output = capture_io(fn -> Print.run(["test/support/songs/arpeggio.exs"]) end)

    assert output == """
           melody, 3 beats at 120 bpm
           beat 0  play 60 sustain: 1
           beat 1  play 64 sustain: 1
           beat 2  play 67 sustain: 1
           """
  end

  @tag :tmp_dir
  test "prints the samples, MIDI, OSC, shared values and changes of a song written as music", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "steps.exs")

    File.write!(path, """
    import Mx

    song(osc_to: {"127.0.0.1", 9000}, music: together([
      part(:drums, seq([sample({:sonic_pi, :bd_haus}, 1), midi(60, 1), midi_cc(74, 64), osc("/hello", [1]), set(:root, 40)])),
      part(:lead, note(:a4, 4, changes: [{1, note: :c5}]), synth: :flute),
      part(:conductor, seq([rest(2), change(:lead, amp: 0.5)]))
    ]))
    """)

    output = capture_io(fn -> Print.run([path]) end)
    assert output =~ "beat 0  sample bd_haus"
    assert output =~ "beat 1  midi 60"
    assert output =~ "beat 2  midi_cc 74, 64"
    assert output =~ "beat 2  osc /hello"
    assert output =~ "beat 2  set root"
    assert output =~ ~r/beat 1 +control note: 72/
    assert output =~ ~r/beat 2 +control amp: 0.5/
  end

  @tag :tmp_dir
  test "prints the pass given of each loop of a song written as music, with the inputs given", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "loops.exs")

    File.write!(path, """
    import Mx

    song(music: part(:bass, loop(1, fn pass, inputs -> note(36 + pass, 1, amp: inputs.cc[74] || 0) end), synth: :saw))
    """)

    output = capture_io(fn -> Print.run([path, "--pass", "4", "--cc", "74=64"]) end)
    assert output =~ "bass, pass 4, 1 beat at 60 bpm\n"
    assert output =~ "beat 0  play 40 amp: 64"
  end

  @tag :tmp_dir
  test "prints each part of a song written as music from the start of the song", %{tmp_dir: dir} do
    path = Path.join(dir, "sections.exs")

    File.write!(path, """
    import Mx

    first = together([part(:trombone, seq(c3: 2, e3: 2), synth: :trombone), part(:flute, seq(r: 2, g5: 2), synth: :flute)])
    second = together([part(:cello, seq(c3: 2, e3: 2), synth: :cello), part(:flute, seq(r: 2, a5: 2), synth: :flute)])
    song(tempo: 72, music: repeat(seq([first, second])))
    """)

    output = capture_io(fn -> Print.run([path]) end)

    assert output == """
           trombone, 8 beats at 72 bpm, played again and again
           beat 0  play 48 sustain: 2
           beat 2  play 52 sustain: 2

           flute, 8 beats at 72 bpm, played again and again
           beat 2  play 79 sustain: 2
           beat 6  play 81 sustain: 2

           cello, 8 beats at 72 bpm, played again and again
           beat 4  play 48 sustain: 2
           beat 6  play 52 sustain: 2
           """
  end

  @tag :tmp_dir
  test "prints each note of a strum at the beat it starts", %{tmp_dir: dir} do
    path = Path.join(dir, "strum.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([note([55, 48, 52], 0, strum: 0.25), rest(1)]) end)))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~ "beat 0     play 48\nbeat 0.25  play 52\nbeat 0.5   play 55\n"
  end

  @tag :tmp_dir
  test "prints a strum's beats rounded to a thousandth", %{tmp_dir: dir} do
    path = Path.join(dir, "strum.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([note([48, 52, 55, 60], 0, strum: 0.025), rest(1)]) end)))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~ "beat 0.075  play 60\n"
  end

  @tag :tmp_dir
  test "prints the steps placed by at at their beats, in order", %{tmp_dir: dir} do
    path = Path.join(dir, "at.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(2, fn _, _ -> at([{1.5, note(60, 0)}, {1, note(60, 0)}, {1, note(72, 0)}], 2) end)))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~
             "a, 2 beats at 60 bpm\nbeat 1    play 60\nbeat 1    play 72\nbeat 1.5  play 60\n"
  end

  @tag :tmp_dir
  test "prints each note of a chord with its own values", %{tmp_dir: dir} do
    path = Path.join(dir, "vel.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([note([45, 52, 57], 0, vel: [0.7, 0.5, 0.4]), rest(1)]) end), synth: :guitar))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~
             "beat 0  play 45 vel: 0.7\nbeat 0  play 52 vel: 0.5\nbeat 0  play 57 vel: 0.4\n"
  end

  @tag :tmp_dir
  test "prints each play step with the loop's defaults it is sent", %{tmp_dir: dir} do
    path = Path.join(dir, "defaults.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), defaults: [amp: 0.5]))\n"
    )

    assert capture_io(fn -> Print.run([path]) end) =~ "beat 0  play 60 amp: 0.5\n"
  end

  @tag :tmp_dir
  test "prints the same values from pick, chance and between each time it prints a pass", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "random.exs")

    File.write!(path, """
    import Mx

    song(music: part(:a, loop(4, fn _, _ ->
      seq(for _ <- 1..8, do: seq(if(chance(0.5), do: [note(pick([60, 62, 64]), 0, amp: between(0.3, 0.9))], else: []) ++ [rest(0.5)]))
    end)))
    """)

    first = capture_io(fn -> Print.run([path]) end)
    assert first =~ ~r/play 6[024] amp: 0\.\d+/
    assert capture_io(fn -> Print.run([path]) end) == first
  end

  test "prints the pass given with --pass" do
    output =
      capture_io(fn ->
        Print.run(["test/support/songs/arpeggio.exs", "--pass", "4"])
      end)

    assert output =~ "melody, pass 4, 3 beats at 120 bpm"
  end

  @tag :tmp_dir
  test "prints the tempos a pass plays at, with the beats of each change in it", %{tmp_dir: dir} do
    path = Path.join(dir, "tempos.exs")

    File.write!(path, """
    import Mx

    song(
      tempo: 100,
      music:
        seq([
          part(:a, seq([tempo(130, over: 16), repeat(seq(c4: 1), 16)])),
          part(:a, seq([rest(4), tempo(140), repeat(seq(d4: 1), 4)])),
          tempo(90, over: 8),
          part(:a, repeat(seq(e4: 1), 4))
        ])
    )
    """)

    print = fn args -> capture_io(fn -> Print.run([path | args]) end) end

    assert print.(["--pass", "0"]) =~
             "a, pass 0, 16 beats at 100 bpm, rising to 130 bpm from beat 0 to 16\n"

    assert print.(["--pass", "1"]) =~ "a, pass 1, 8 beats at 130 bpm, then 140 bpm from beat 4\n"

    assert print.(["--pass", "2"]) =~
             "a, pass 2, 4 beats at 140 bpm, falling to 90 bpm from beat 0 to 8\n"

    assert print.([]) =~
             "a, 28 beats at 100 bpm, rising to 130 bpm from beat 0 to 16, then 140 bpm from beat 20, falling to 90 bpm from beat 24 to 32\n"
  end

  @tag :tmp_dir
  test "prints play options and fractional beats", %{tmp_dir: dir} do
    path = Path.join(dir, "half.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1.0, fn _, _ -> seq([note(60, 0, amp: 0.5), rest(0.5), note(62, 0, release: 1), rest(0.5)]) end)))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~ "beat 0    play 60 amp: 0.5\n"
    assert output =~ "beat 0.5  play 62 release: 1\n"
    assert output =~ "a, 1 beat at 60 bpm\n"
  end

  @tag :tmp_dir
  test "prints a pass of each part, in the order of the song", %{tmp_dir: dir} do
    path = Path.join(dir, "band.exs")

    File.write!(
      path,
      "import Mx\nsong(music: together([part(:drums, loop(4, fn _, _ -> seq([note(36, 0), rest(4)]) end)), part(:bass, loop(4, fn _, _ -> seq([note(40, 0), rest(4)]) end))]))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output == """
           drums, 4 beats at 60 bpm
           beat 0  play 36

           bass, 4 beats at 60 bpm
           beat 0  play 40
           """
  end

  @tag :tmp_dir
  test "prints note names as the numbers they play", %{tmp_dir: dir} do
    path = Path.join(dir, "names.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([note(:c4, 0), rest(1)]) end)))\n"
    )

    assert capture_io(fn -> Print.run([path]) end) =~ "beat 0  play 60\n"
  end

  @tag :tmp_dir
  test "prints samples as they are written", %{tmp_dir: dir} do
    path = Path.join(dir, "drums.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(1, fn _, _ -> seq([sample({:sonic_pi, :bd_haus}, 0, rate: 2), rest(1)]) end)))\n"
    )

    assert capture_io(fn -> Print.run([path]) end) =~
             "beat 0  sample bd_haus rate: 2\n"
  end

  @tag :tmp_dir
  test "prints the effects of each loop, in order", %{tmp_dir: dir} do
    path = Path.join(dir, "fx.exs")

    File.write!(
      path,
      "import Mx\nsong(music: together([part(:a, loop(1, fn _, _ -> seq([note(60, 0), rest(1)]) end), fx: [echo: [phase: 0.25], reverb: []]), part(:b, loop(1, fn _, _ -> seq([note(62, 0), rest(1)]) end))]))\n"
    )

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~ "a, 1 beat at 60 bpm, through echo (phase: 0.25) then reverb\n"
    assert output =~ "b, 1 beat at 60 bpm\n"
  end

  @tag :tmp_dir
  test "prints control steps with their beat and options", %{tmp_dir: dir} do
    path = Path.join(dir, "control.exs")

    File.write!(
      path,
      "import Mx\nsong(music: part(:a, loop(2, fn _, _ -> seq([note(60, 0, sustain: 4, changes: [{1, note: 65}]), rest(2)]) end)))\n"
    )

    assert capture_io(fn -> Print.run([path]) end) =~ "beat 1  control note: 65\n"
  end

  @tag :tmp_dir
  test "prints MIDI and OSC steps with their beat", %{tmp_dir: dir} do
    path = Path.join(dir, "out.exs")

    File.write!(path, """
    import Mx

    song(osc_to: {"localhost", 9000}, music: part(:a, loop(2, fn _, _ ->
      at([{0, midi(60, 0.5)}, {1, midi_cc(74, 64)}, {1, osc("/hello", [1, "a"])}], 2)
    end)))
    """)

    output = capture_io(fn -> Print.run([path]) end)

    assert output =~ "beat 0  midi 60 velocity: 100, channel: 1, length: 0.5\n"
    assert output =~ "beat 1  midi_cc 74, 64 channel: 1\n"
    assert output =~ ~s(beat 1  osc /hello [1, "a"]\n)
  end

  @tag :tmp_dir
  test "prints a pass as if the inputs and values given had arrived", %{tmp_dir: dir} do
    path = Path.join(dir, "in.exs")

    File.write!(path, """
    import Mx

    song(music: together([
      part(:a, loop(1, fn _, inputs ->
        seq([
          note(inputs.cc[74] || 1, 0),
          note(inputs.notes[60] || 2, 0),
          note(hd(inputs.osc["/x"] || [3]), 0),
          note(inputs.values[:root] || 4, 0),
          set(:root, 41),
          rest(1)
        ])
      end)),
      part(:keys, loop(fn trigger, _ -> note(trigger.note, 1) end, on: :midi_note))
    ]))
    """)

    given = ["--cc", "74=64", "--note", "60=100", "--osc", "/x=50,a", "--get", "root=40"]
    output = capture_io(fn -> Print.run([path | given]) end)

    assert output =~
             "beat 0  play 64\nbeat 0  play 100\nbeat 0  play 50\nbeat 0  play 40\nbeat 0  set root 41\n"

    assert output =~ "keys plays a pass on each MIDI note on\n"

    plain = capture_io(fn -> Print.run([path]) end)
    assert plain =~ "beat 0  play 1\nbeat 0  play 2\nbeat 0  play 3\nbeat 0  play 4\n"
  end

  @tag :tmp_dir
  test "stops with the error when the file cannot be loaded", %{tmp_dir: dir} do
    path = Path.join(dir, "empty.exs")
    File.write!(path, "import Mx\n")

    assert_raise Mix.Error, ~r/does not end with a song/, fn -> Print.run([path]) end
  end
end
