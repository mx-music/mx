defmodule StillWater do
  @moduledoc """
  Still Water, a slow piece for the sounds of VCSL that are held rather than struck, Versilian
  Studios' Versilian Community Sample Library, under Creative Commons 0: didgeridoo, two ocarinas,
  wine glasses, ocean drum, Nepalese hand bells, darbuka, and the toy train whistle, ball whistle
  and siren whistle.
  The didgeridoo's note is the C sharp two octaves below middle C, and it is recorded as long
  notes and phrases of ten to fifteen seconds, so the piece lays one after another as a drone from
  beginning to end.
  Over it the wine glasses hold D sharp, F sharp and B, the larger ocarina plays a tune in the
  five notes C sharp, E, F sharp, G sharp and B, and the small ocarina answers it an octave above.
  Two of the glasses and the darbuka were recorded a little off those notes, so each is played at
  the rate that brings it to them.
  The tempo is 60, so a beat is a second.
  VCSL names the ocarinas' keys an octave below the pitch mx names them by.
  The files are fetched as the song loads, about 120 MB.
  """

  use Mx.Song, tempo: 60

  vcsl = fn path -> {:vcsl, path} end

  didgeridoo = fn name ->
    vcsl.("Aerophones/Lip Aerophones/Didgeridoo/Didgeridoo1_#{name}_Main.wav")
  end

  glass = fn path -> vcsl.("Idiophones/Friction Idiophones/Wine Glasses/Sustains/#{path}") end
  blown = fn path -> vcsl.("Aerophones/Edge-blown Aerophones/#{path}") end

  darbuka = fn name ->
    vcsl.("Membranophones/Struck Membranophones/Darbuka/Darbuka_#{name}_hit_vl2_rr1.wav")
  end

  bell = fn name -> vcsl.("Idiophones/Struck Idiophones/Hand Bells, Nepalese/HB_#{name}.wav") end

  # Each sound as its file and the options it plays with: the gain that brings it level with the
  # others, and the rate where it needs tuning.
  @sounds %{
    long_note: {didgeridoo.("Sus2"), amp: 3.5},
    second_note: {didgeridoo.("Sus3"), amp: 1.2},
    high_note: {didgeridoo.("Sus8"), amp: 1.4},
    phrase: {didgeridoo.("Phrase1"), amp: 0.7},
    second_phrase: {didgeridoo.("Phrase3"), amp: 0.6},
    third_phrase: {didgeridoo.("Phrase8"), amp: 1.2},
    glass_ds: {glass.("Slow/glass1_D#4_Slow_1_Main.wav"), amp: 6.0, rate: 0.983},
    glass_fs: {glass.("Slow/glass2_F#4_Slow_1_Main.wav"), amp: 10.0},
    glass_b: {glass.("Slow/glass3_A#4_Slow_1_Main.wav"), amp: 7.0, rate: 1.023},
    fast_glass: {glass.("Fast/glass1_D#4_Fast_1_main.wav"), amp: 2.0, rate: 0.983},
    ocean:
      {vcsl.("Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_1_Mid.wav"), amp: 12.0},
    second_ocean:
      {vcsl.("Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_2_Mid.wav"), amp: 12.0},
    bell: {bell.("1"), amp: 1.5},
    low_bell: {bell.("2"), amp: 1.2},
    high_bell: {bell.("3"), amp: 5.0},
    train: {blown.("Train Whistle, Toy/Main_TrainLow_Double-001.wav"), amp: 3.0},
    ball: {blown.("Ball Whistle/Main_BallWhistle_Long-001.wav"), amp: 0.25},
    siren: {vcsl.("Aerophones/Free Aerophones/Siren/Main_SirenWhistle-008.wav"), amp: 3.0},
    doum: {darbuka.("1"), amp: 0.25, rate: 0.962},
    tek: {darbuka.("3"), amp: 0.5, rate: 0.962}
  }

  ocarina = fn folder, prefix, suffix, names ->
    for name <- names do
      note = name |> String.downcase() |> String.replace("#", "s") |> Mx.Notes.parse()
      {blown.("#{folder}/#{prefix}#{name}#{suffix}.wav"), note: pitch(note) + 12}
    end
  end

  @ocarina ocarina.(
             "Ocarina, Typical/Sustains/Sus",
             "StdOcarina_Sus_",
             "",
             ~w(A3 B3 C#4 D4 E4 F#4 G#4 A4 A#4 C5 C#5)
           )
  @small_ocarina ocarina.(
                   "Ocarina, Small/Sustain",
                   "ocarina_",
                   "_sustain0",
                   ~w(C5 D5 E5 F5 G5 G#5 A5 A#5 B5)
                 )

  @far [room: 0.9, mix: 0.5]
  @near [room: 0.8, mix: 0.3]

  part :didgeridoo, fx: [level: [amp: 5.0], reverb: [room: 0.7, mix: 0.2]]
  part :glasses, fx: [level: [amp: 0.9], reverb: @far, pan: [pan: 0.3]]
  part :water, fx: [level: [amp: 3.0], reverb: @near]
  part :bells, fx: [level: [amp: 2.5], reverb: @far, pan: [pan: -0.3]]
  part :whistles, fx: [level: [amp: 2.0], reverb: @far, pan: [pan: -0.4]]
  part :darbuka, fx: [level: [amp: 1.5], reverb: @near, pan: [pan: 0.15]]

  part :ocarina,
    synth: sampled(@ocarina),
    defaults: [attack: 0.05, release: 0.4],
    fx: [level: [amp: 0.6], reverb: @near, pan: [pan: -0.15]]

  part :small_ocarina,
    synth: sampled(@small_ocarina),
    defaults: [attack: 0.05, release: 0.4],
    fx: [level: [amp: 1.5], reverb: @far, pan: [pan: 0.25]]

  @length 100

  def song do
    together([
      sounds(
        :didgeridoo,
        [
          {6, :long_note},
          {16, :high_note},
          {28, :second_note},
          {36, :phrase},
          {46, :second_phrase}
        ] ++
          [{60, :long_note}, {70, :third_phrase}, {81, :high_note}]
      ),
      sounds(
        :glasses,
        [
          {12, :glass_fs},
          {20, :glass_ds},
          {30, :glass_b},
          {56, :glass_fs},
          {62, :glass_b},
          {70, :fast_glass}
        ]
      ),
      sounds(:water, [{0, :ocean}, {36, :second_ocean}, {58, :ocean}]),
      sounds(
        :bells,
        [{2, :bell}, {26, :bell}, {38, :high_bell}, {50, :bell}, {62, :high_bell}, {74, :bell}] ++
          [{86, :low_bell}, {92, :bell}]
      ),
      sounds(:whistles, [{44, :ball}, {52, :train}, {66, :siren}]),
      sounds(:darbuka, darbuka()),
      notes(:ocarina, [
        {24, :cs5, 2},
        {26, :e5, 1},
        {27, :fs5, 3},
        {30, :gs5, 2},
        {32, :fs5, 1},
        {33, :e5, 1},
        {34, :cs5, 4},
        {38, :b4, 1},
        {39, :cs5, 1},
        {40, :e5, 2},
        {42, :fs5, 1},
        {43, :gs5, 1},
        {44, :b5, 4},
        {48, :gs5, 2},
        {50, :fs5, 2},
        {52, :e5, 1},
        {53, :cs5, 5},
        {72, :e5, 2},
        {74, :fs5, 2},
        {76, :cs5, 6}
      ]),
      notes(:small_ocarina, [
        {58, :e6, 2},
        {60, :fs6, 1},
        {61, :gs6, 3},
        {64, :fs6, 1},
        {65, :e6, 1},
        {66, :cs6, 4},
        {72, :e6, 2},
        {74, :fs6, 2},
        {76, :cs6, 6}
      ])
    ])
  end

  # A part from its sounds and the seconds they start at.
  defp sounds(name, entries) do
    hits =
      for {second, sound} <- entries do
        {file, options} = @sounds[sound]
        {second, sample(file, 0, options)}
      end

    part(name, at(hits, @length))
  end

  # The darbuka's slow figure from second 40 to second 72: a low stroke and two high ones every
  # four seconds.
  defp darbuka do
    for bar <- 0..7, {offset, sound} <- [{0, :doum}, {1.5, :tek}, {3, :tek}] do
      {40 + bar * 4 + offset, sound}
    end
  end

  # A part from its notes: each the second it starts at, the note, and how long it is held.
  defp notes(name, entries) do
    hits = for {second, pitches, seconds} <- entries, do: {second, note(pitches, seconds)}
    part(name, at(hits, @length))
  end
end
