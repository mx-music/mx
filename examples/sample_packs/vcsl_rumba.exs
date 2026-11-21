defmodule RumbaYMontuno do
  @moduledoc """
  Rumba y Montuno, for the Afro-Cuban percussion of VCSL, Versilian Studios' Versilian Community
  Sample Library, under Creative Commons 0: claves, woodblock, cajón, the three congas, cabasa,
  bongos, cowbell, güiro, agogo bells and vibraslap, with its xylophone.
  Everything is counted from the rumba clave, five strokes in sixteen pulses, which the claves
  play from the first bar to the last.
  The first half is a guaguancó as it is commonly taught: sticks on the woodblock, and a melody of
  three open tones between the low drum and the middle one, which the cajón plays first, as rumba
  was played on boxes before it was played on drums; over it the quinto, the high drum, plays
  alone.
  The second half is a montuno: the congas change to the tumbao of dance music, the bongos play
  the martillo, the cowbell and the güiro come in, and the xylophone plays the figure a piano
  would, C, F, G and F, and then a tune over it.
  Each row is sixteen pulses, a character to each: a digit is a stroke of that level and a dot is
  silence.
  The pack records its instruments at very different levels, so each sound has its own gain.
  The files are fetched as the song loads, about 15 MB.
  """

  use Mx.Song, tempo: 112

  vcsl = fn path -> {:vcsl, path} end
  drum = fn path -> vcsl.("Membranophones/Struck Membranophones/#{path}") end
  struck = fn path -> vcsl.("Idiophones/Struck Idiophones/#{path}") end

  # Each sound's file and the gain that brings it level with the others.
  @sounds %{
    tumba_open: {drum.("Conga/Tumba_HitN_v4_rr1_Sum.wav"), 3.0},
    tumba_mute: {drum.("Conga/Tumba_HitFM_v3_rr1_Sum.wav"), 3.0},
    conga_open: {drum.("Conga/Conga_HitN_v3_rr1_Sum.wav"), 1.6},
    conga_slap: {drum.("Conga/Conga_HitFM_v2_rr1_Sum.wav"), 0.9},
    conga_mute: {drum.("Conga/Conga_HitFM_v1_rr1_Sum.wav"), 5.0},
    quinto_open: {drum.("Conga/Quinto_HitN_v3_rr1_Sum.wav"), 1.2},
    quinto_slap: {drum.("Conga/Quinto_HitFM1_v2_rr1_Sum.wav"), 2.4},
    bongo_high: {drum.("Bongos/BongoH_Hit1_v3_rr1_Mid.wav"), 0.7},
    bongo_mute: {drum.("Bongos/BongoH_HitMuted1_v2_rr1_Mid.wav"), 1.1},
    bongo_low: {drum.("Bongos/BongoL_Hit1_v3_rr1_Mid.wav"), 0.8},
    clave: {struck.("Claves/Claves1_Hit_v3_rr1_Mid.wav"), 1.3},
    stick: {struck.("Woodblock/wood_click_f_rr1.wav"), 0.6},
    cajon_bass: {struck.("Cajon/Cajon_hit2_f_rr1.wav"), 0.35},
    cajon_tone: {struck.("Cajon/Cajon_hit1_f_rr1.wav"), 0.6},
    cajon_slap: {struck.("Cajon/Cajon_hit3_f_rr1.wav"), 0.25},
    cabasa_hit: {struck.("Cabasa/Cabasa1_Hit_rr1_Mid.wav"), 2.0},
    cabasa_rub: {struck.("Cabasa/Cabasa1_Rub_v2_rr1_Mid.wav"), 2.0},
    bell_open: {struck.("Cowbells/Cowbell2_Normal_v3_rr1_Mid.wav"), 0.35},
    bell_closed: {struck.("Cowbells/Cowbell2_Muted_v3_rr1_Mid.wav"), 0.4},
    guiro_long: {struck.("Guiro/Guiro_Fast_rr1_Mid.wav"), 9.0},
    guiro_short: {struck.("Guiro/Guiro_Hit_rr1_Mid.wav"), 12.0},
    agogo_high: {struck.("Agogo Bells/Agogo_High_v3_rr1_Mid.wav"), 2.0},
    agogo_low: {struck.("Agogo Bells/Agogo_Low_v2_rr1_Mid.wav"), 3.0},
    vibraslap: {struck.("Vibraslap/Legacy/vibraslap_rr1.wav"), 3.0}
  }

  xylophone = fn mallets, prefix ->
    for name <- ~w(G3 C4 G4 C5 G5 C6 G6 C7) do
      note = name |> String.downcase() |> Mx.Notes.parse()
      path = "Xylophone/#{mallets} Mallets/Xylo_#{prefix}_#{name}_ff_01_far.wav"
      {struck.(path), note: pitch(note) + 12}
    end
  end

  @medium xylophone.("Medium", "Medium")
  @hard xylophone.("Hard", "Hard")

  @room [room: 0.5, mix: 0.15]

  part :claves, fx: [level: [amp: 2.6], reverb: @room, pan: [pan: 0.1]]
  part :sticks, fx: [level: [amp: 1.8], reverb: @room, pan: [pan: -0.4]]
  part :cajon, fx: [level: [amp: 2.4], reverb: @room, pan: [pan: -0.1]]
  part :congas, fx: [level: [amp: 2.0], reverb: @room, pan: [pan: -0.2]]
  part :quinto, fx: [level: [amp: 2.4], reverb: @room, pan: [pan: 0.25]]
  part :shakers, fx: [level: [amp: 2.5], reverb: @room, pan: [pan: 0.45]]
  part :bongos, fx: [level: [amp: 2.4], reverb: @room, pan: [pan: 0.3]]
  part :bells, fx: [level: [amp: 1.8], reverb: @room, pan: [pan: -0.35]]

  part :xylophone,
    synth: sampled(@medium),
    fx: [level: [amp: 0.4], reverb: @room, pan: [pan: -0.1]]

  part :tune, synth: sampled(@hard), fx: [level: [amp: 0.7], reverb: @room, pan: [pan: 0.1]]

  @pulse 0.25

  @clave "8..8...8..8.8..."
  @sticks "7.57.5.75.7.57.5"

  # The quinto's eight cycles, o its open tone and s its slap.
  @quinto [
    "....o..o....s...",
    "..o..o..o...s.o.",
    "....o.oo....s...",
    "o..o..o..o..s.s.",
    "..oo..oo..oo.s..",
    "s..s..s.o.o.o...",
    "..o.o.o.s..oo.oo",
    "o..o..o.s...s..."
  ]

  def song do
    seq([
      together(claves: claves(4), sticks: seq([rest(8), sticks(2)])),
      together(claves: claves(4), sticks: sticks(4), cajon: cajon(4)),
      together(claves: claves(4), sticks: sticks(4), congas: guaguanco(4), shakers: cabasa(4)),
      together(
        claves: claves(8),
        sticks: sticks(8),
        congas: guaguanco(8),
        shakers: cabasa(8),
        quinto: quinto()
      ),
      break(),
      together(
        claves: claves(4),
        congas: tumbao(4),
        bongos: martillo(4),
        bells: bell(4),
        shakers: guiro(4),
        xylophone: montuno(4)
      ),
      together(
        claves: claves(8),
        congas: tumbao(8),
        bongos: martillo(8),
        bells: together([bell(8), agogo(8)]),
        shakers: guiro(8),
        xylophone: montuno(8),
        tune: tune(4)
      ),
      break(),
      together(
        congas: rows(conga_open: "8...............", tumba_open: "8..............."),
        bongos: rows(bongo_low: "8..............."),
        bells: rows(bell_open: "8...............", vibraslap: "7..............."),
        xylophone: together([note([:c5, :e5, :g5, :c6], 4), rest(8)])
      )
    ])
  end

  defp claves(times), do: rows([clave: @clave], times)
  defp sticks(times), do: rows([stick: @sticks], times)

  # The guaguancó's melody on the cajón: the bass, and two tones that answer it.
  defp cajon(times) do
    rows(
      [
        cajon_bass: "......8.......5.",
        cajon_tone: "...........78...",
        cajon_slap: "..3.....3......."
      ],
      times
    )
  end

  # The same melody on the low drum and the middle one, with the quiet strokes that fill it.
  defp guaguanco(times) do
    rows(
      [
        tumba_open: "......8.......5.",
        tumba_mute: "3..3......3.....",
        conga_open: "...........78...",
        conga_mute: "2.2.2...2.....2.",
        conga_slap: "....4..........."
      ],
      times
    )
  end

  defp cabasa(times) do
    rows([cabasa_hit: "6...6...6...6...", cabasa_rub: "..4...4...4...4."], times)
  end

  defp quinto do
    row = fn letter -> Enum.map(@quinto, &String.replace(&1, ~r/[^.#{letter}]/, ".")) end
    opens = Enum.map(row.("o"), &String.replace(&1, "o", "8"))
    slaps = Enum.map(row.("s"), &String.replace(&1, "s", "7"))
    rows(quinto_open: opens, quinto_slap: slaps)
  end

  # Everyone on the clave's five strokes, and the vibraslap after the last.
  defp break do
    together(
      claves: claves(1),
      sticks: rows(stick: @clave),
      congas: rows(conga_slap: @clave, tumba_open: @clave),
      quinto: rows(quinto_slap: @clave),
      bells: rows(vibraslap: "..............7.")
    )
  end

  # The tumbao: quiet strokes, a slap in each half, two tones on the middle drum and two on the
  # low one.
  defp tumbao(times) do
    rows(
      [
        conga_mute: "33.333..33.333..",
        conga_slap: "..6.......6.....",
        conga_open: "......77........",
        tumba_open: "..............77"
      ],
      times
    )
  end

  # The martillo: the small drum on every pulse, strong and quiet in turn, and the large one on
  # the seventh of each eight.
  defp martillo(times) do
    rows(
      [
        bongo_high: "8.5.7...8.5.7...",
        bongo_mute: ".4.4.4.4.4.4.4.4",
        bongo_low: "......7.......7."
      ],
      times
    )
  end

  defp bell(times) do
    rows([bell_open: "8...8...8...8...", bell_closed: "..55..55..5...55"], times)
  end

  defp guiro(times) do
    rows([guiro_long: "7...7...7...7...", guiro_short: "..55..55..55..55"], times)
  end

  # The figure a piano would play: each chord's notes, the next chord's coming a pulse early.
  defp montuno(times) do
    repeat(
      figure([
        {0, [:c5, :c6]},
        {2, :e5},
        {3, :g5},
        {4, [:c5, :c6]},
        {5, :f5},
        {6, :a5},
        {7, [:d5, :d6]},
        {9, :g5},
        {10, :b5},
        {11, [:d5, :d6]},
        {13, :f5},
        {14, :a5},
        {15, [:c5, :c6]}
      ]),
      times
    )
  end

  defp agogo(times) do
    rows([agogo_high: "7.7...7.7.....7.", agogo_low: "...7.7.....7.7.."], times)
  end

  defp tune(times) do
    first = [
      {0, :e6},
      {2, :g6},
      {3, :e6},
      {5, :f6},
      {6, :a6},
      {7, :g6},
      {9, :d6},
      {10, :g6},
      {11, :b6},
      {13, :a6},
      {14, :f6},
      {15, :e6}
    ]

    second = [
      {0, :g6},
      {2, :c7},
      {3, :g6},
      {5, :a6},
      {6, :c7},
      {7, :b6},
      {9, :g6},
      {10, :b6},
      {11, :d7},
      {13, :c7},
      {14, :a6},
      {15, :g6}
    ]

    repeat(seq([figure(first), figure(second)]), times)
  end

  # Rows of sounds played together, each row one cycle or several in turn, the whole played so
  # many times.
  defp rows(rows, times \\ 1) do
    together(
      for {sound, patterns} <- rows do
        {file, gain} = @sounds[sound]

        cycles =
          for pattern <- List.wrap(patterns) do
            hits =
              for {cell, index} <- Enum.with_index(String.graphemes(pattern)), cell != "." do
                amp = gain * String.to_integer(cell) / 9
                {index * @pulse, sample(file, 0, amp: amp)}
              end

            at(hits, 4)
          end

        repeat(seq(cycles), times)
      end
    )
  end

  # A cycle of the xylophone from the notes at each pulse.
  defp figure(notes) do
    notes = for {pulse, name} <- notes, do: {pulse * @pulse, note(name, @pulse)}
    at(notes, 4)
  end
end
