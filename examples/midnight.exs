defmodule Midnight do
  @moduledoc """
  A hypnotic piece in raga Darbari Kanada, the grave raga of midnight, on Sa F, laid out as a
  recital: alap, a slow gat, a fast gat ending on a tihai, and shanti.
  Wikipedia gives its ascent as S R g, g M P d n S' and its descent as S' d n P M P g, g M R S,
  komal Ga and komal Dha swung slowly in andolan, mostly in the lower octave; Raganet and
  Ragajunglism give g M R S and d n P as its defining phrases, and Ga touched from Re on the way
  up and from Ma on the way down.
  The oboe plays it as a shehnai would, the double reed of Hindustani music: each phrase slurred
  on one breath, the fingers moving from note to note, gliding in meend where the raga asks, and
  tongued again only to start a breath or repeat a note.
  The harmonium cannot glide, so it plays its notes plainly: in the alap it answers the end of
  each of the oboe's phrases, as an accompanist fills the soloist's breath, and in the gat it
  follows the composition but not its taans.
  Under the gat two pianos phase as in Steve Reich's Piano Phase: both repeat one figure, and
  every pass the second locks in for eight beats, then drifts a sixteenth ahead over the next
  eight, until twelve passes bring them back to unison.
  """

  use Mx.Song, tempo: 60

  @sa 65

  part :tanpura,
    synth: :tanpura,
    defaults: [amp: 0.45, pan: -0.15],
    fx: [flanger: [phase: 32, feedback: 0.3, mix: 0.25]]

  part :organ,
    synth: :organ,
    fx: [
      wobble: [phase: 32, cutoff_min: 38, cutoff_max: 72, res: 0.3, wave: 3],
      reverb: [room: 0.9, mix: 0.45]
    ]

  part :chorus,
    synth: :organ,
    defaults: [amp: 0.5],
    fx: [
      slicer: [phase: 0.5, amp_min: 0.2, smooth: 0.03],
      wobble: [phase: 24, cutoff_min: 70, cutoff_max: 115, res: 0.4, wave: 3],
      reverb: [room: 0.9, mix: 0.45]
    ]

  part :oboe,
    synth: :oboe,
    defaults: [pan: 0.1],
    fx: [
      ping_pong: [phase: 1.5, feedback: 0.6, mix: 0.5],
      reverb: [room: 0.85, mix: 0.4]
    ]

  part :ghost,
    synth: :oboe,
    defaults: [amp: 0.22],
    fx: [
      echo: [phase: 3, decay: 10, mix: 1],
      reverb: [room: 0.95, mix: 0.7]
    ]

  part :stars,
    synth: :vibraphone,
    defaults: [amp: 1.2],
    fx: [
      ping_pong: [phase: 1, feedback: 0.6, mix: 0.5],
      reverb: [room: 0.95, mix: 0.6]
    ]

  part :harmonium,
    synth: :harmonium,
    defaults: [amp: 3, pan: -0.3],
    fx: [
      chorus: [mix: 0.4],
      echo: [phase: 0.75, decay: 4, mix: 0.3],
      reverb: [room: 0.8, mix: 0.35]
    ]

  part :piano,
    synth: :piano,
    defaults: [amp: 2.5, pan: -0.6],
    fx: [
      wobble: [phase: 24, cutoff_min: 68, cutoff_max: 118, res: 0.5, wave: 3],
      ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.25],
      reverb: [room: 0.85, mix: 0.4]
    ]

  part :piano_phase,
    synth: :piano,
    defaults: [amp: 2.5, pan: 0.6],
    fx: [
      wobble: [phase: 20, cutoff_min: 68, cutoff_max: 118, res: 0.5, wave: 3],
      reverb: [room: 0.85, mix: 0.4]
    ]

  part :tabla_na,
    synth: :tabla_na,
    defaults: [note: @sa, amp: 0.7, pan: 0.2],
    fx: [ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.2], reverb: [room: 0.7, mix: 0.2]]

  part :tabla_tun,
    synth: :tabla_tun,
    defaults: [note: @sa, amp: 0.7, pan: 0.2],
    fx: [ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.2], reverb: [room: 0.7, mix: 0.2]]

  part :tabla_te, synth: :tabla_te, defaults: [amp: 0.7, pan: 0.2]
  part :tabla_ghe, synth: :tabla_ghe, defaults: [amp: 0.5, pan: 0.15]

  part :clave,
    synth: :clave,
    defaults: [amp: 0.5, pan: 0.45],
    fx: [echo: [phase: 0.75, decay: 3, mix: 0.35], reverb: [room: 0.8, mix: 0.3]]

  part :guiro,
    synth: :guiro,
    defaults: [amp: 0.5, pan: -0.45],
    fx: [
      flanger: [phase: 8, feedback: 0.3, mix: 0.3],
      ping_pong: [phase: 0.75, feedback: 0.4, mix: 0.25]
    ]

  # The alap opens over the drones, the slow gat brings in the tabla, the güiro and the pianos,
  # the fast gat the claves, and shanti settles back on Sa.
  def song do
    passes =
      for {section, count} <- [alap: 4, vilambit: 4, drut: 9, shanti: 2],
          time <- 0..(count - 1),
          do: pass(section, time)

    repeat(seq(passes))
  end

  # A pass of a section, given how many of its passes came before.
  defp pass(section, time) do
    together([
      part(:tanpura, tanpura(section, time)),
      part(:organ, organ(section, time)),
      part(:chorus, chorus(section, time)),
      part(:oboe, oboe(section, time)),
      part(:ghost, ghost(section, time)),
      part(:stars, stars(section, time)),
      part(:harmonium, harmonium(section, time)),
      part(:piano, piano(section, time)),
      part(:piano_phase, piano_phase(section, time)),
      part(:tabla_na, tabla(section, time, :tabla_na)),
      part(:tabla_tun, tabla(section, time, :tabla_tun)),
      part(:tabla_te, tabla(section, time, :tabla_te)),
      part(:tabla_ghe, tabla(section, time, :tabla_ghe)),
      part(:clave, clave(section, time)),
      part(:guiro, guiro(section, time))
    ])
  end

  # The drone sounds from the first beat through the whole piece.
  defp tanpura(:alap, 0), do: note(@sa - 12, 16, vel: 0.5, gap: 1, sustain: length())
  defp tanpura(_section, _time), do: rest(16)

  # The organ's stopped flute holds low Sa and Pa as a pedal point from the first beat to the
  # last.
  defp organ(:alap, 0), do: note([@sa - 24, @sa - 17], 16, sustain: length(), release: 4)
  defp organ(_section, _time), do: rest(16)

  # For the fast gat's last five passes the organist adds the principal chorus on Sa, Pa and Sa,
  # held into the tihai's landing.
  defp chorus(:drut, 4) do
    note([@sa - 12, @sa - 5, @sa], 16, loud: 1, sustain: 5 * 16, release: 2)
  end

  defp chorus(_section, _time), do: rest(16)

  # A token's parts: ~ glides into the note from the one before, a note in brackets before it is a
  # kan touched just before it, and = swings it in andolan.
  defp parse(token) do
    [_, glide, kan, name, andolan] = Regex.run(~r/^(~?)(?:\((.+)\))?([^=()~]+)(=?)$/, token)
    %{glide: glide == "~", kan: if(kan != "", do: kan), name: name, andolan: andolan == "="}
  end

  # The oboe's unmetered lines: each token is a note and its length in beats, and - rests; every
  # line ends on a rest for the harmonium's answer.
  defp line(:alap, 0), do: "S:3 .n:1 ~.P:2 .d=:2 ~.n:1 ~S:3 -:4"
  defp line(:alap, 1), do: ".n:1 S:1 R:2 (R)g=:3 M:1 ~R:1.5 ~S:2.5 -:4"
  defp line(:alap, 2), do: "M:1 P:1.5 d=:2.5 ~n:1 P:2 M:1 P:1 (M)g=:2 -:4"
  defp line(:alap, 3), do: "M:1 P:1 n:1 S':3 d=:1.5 ~n:0.5 P:1.5 (M)g=:1 M:0.5 ~R:1 S:1 -:3"
  defp line(:shanti, 0), do: "S:6 .n:1 ~.d=:3 ~.n:1 ~S:5"
  defp line(:shanti, 1), do: "-:4 (R)g=:4 M:1 ~R:2 ~S:5"

  defp tokens(line) do
    for token <- String.split(line) do
      [name, beats] = String.split(token, ":")
      {beats, _} = Float.parse(beats)
      {name, beats}
    end
  end

  # The gat, one cell to each matra: a cell of several notes divides its matra evenly, and - holds
  # the note before.
  defp cells(:sthayi), do: String.split("S - .n S R - (R)g= - M R S - .d .n .P -")

  defp cells(:antara), do: String.split("M P n - S' - d= n P - M P (M)g= M R S")

  defp cells(:taan) do
    ["S R", "g M", "P d", "n P", "M P", "g M", "R S", ".n S"] ++
      ["R g", "M P", "d n", "S' -", "d n", "P M", "P g", "M R S"]
  end

  defp cells(:fast_taan) do
    ["S R g M", "P d n P", "M P g M", "R S .n S", "R g M P", "d n S' R'", "S' d n P"] ++
      ["M P g M", "R S R g", "M P d n", "P M P g", "M R S -", "S' d n P", "M P g M"] ++
      ["R S .n S", "-"]
  end

  # Three times (M)g M R S, a matra apart, the last Sa landing on the sam of shanti.
  defp cells(:tihai) do
    ["S' d", "n P", "M P"] ++ String.split("(M)g M R S - (M)g M R S - (M)g M R")
  end

  defp gat(:vilambit, time), do: Enum.at([:sthayi, :sthayi, :antara, :sthayi], time)

  defp gat(:drut, time) do
    Enum.at(
      [:taan, :antara, :taan, :sthayi, :fast_taan, :antara, :fast_taan, :sthayi, :tihai],
      time
    )
  end

  # The notes of a gat part as {beat, token, length}, a held cell lengthening the note before it.
  defp notes(part) do
    part
    |> cells()
    |> Enum.with_index()
    |> Enum.flat_map(fn {cell, matra} ->
      tokens = String.split(cell)

      Enum.with_index(tokens, fn token, index ->
        {matra + index / length(tokens), token, 1 / length(tokens)}
      end)
    end)
    |> Enum.reduce([], fn
      {_, "-", length}, [{beat, token, held} | rest] -> [{beat, token, held + length} | rest]
      note, notes -> [note | notes]
    end)
    |> Enum.reverse()
  end

  # The changes one stretch of a breath makes from beat at: a glide slides slowly into its note in
  # meend, any other note is slurred to by the fingers,
  # a kan is touched on the way in, and andolan swings the note down towards the note below and
  # back every half beat.
  defp changes(swara, at, beats, base) do
    pitch = swara(swara.name, base)

    into =
      cond do
        at == 0 and swara.kan ->
          [{0.12, note: pitch, note_slide: 0.06}]

        at == 0 ->
          []

        swara.glide ->
          [{at, note: pitch, note_slide: 0.6}]

        swara.kan ->
          [
            {at, note: swara(swara.kan, base), note_slide: 0.05},
            {at + 0.12, note: pitch, note_slide: 0.06}
          ]

        true ->
          [{at, note: pitch, note_slide: 0.08}]
      end

    swings =
      (at + 0.5)
      |> Stream.iterate(&(&1 + 0.5))
      |> Enum.take_while(&(swara.andolan and &1 < at + beats - 0.5))

    swings = Enum.take(swings, length(swings) - rem(length(swings), 2))

    into ++
      Enum.with_index(swings, fn offset, index ->
        {offset, note: if(rem(index, 2) == 0, do: pitch - 0.6, else: pitch), note_slide: 0.45}
      end)
  end

  # One breath of the oboe through its stretches, each {swara, beats}, starting on the first one's
  # kan if it has one.
  defp breath([{first, _} | _] = stretches, base, vel) do
    held = Enum.sum(Enum.map(stretches, &elem(&1, 1)))

    {changes, _} =
      Enum.flat_map_reduce(stretches, 0, fn {swara, beats}, at ->
        {changes(swara, at, beats, base), at + beats}
      end)

    note(swara(first.kan || first.name, base), held,
      vel: vel,
      sustain: held - min(held * 0.15, 0.35),
      release: min(held * 0.3, 0.3),
      changes: changes
    )
  end

  # Notes as {beat, swara, beats} grouped into breaths: the oboe tongues a note only to repeat the
  # one it holds, after a note of longest beats, or once a breath has lasted 8 beats.
  defp breaths(notes, longest) do
    Enum.chunk_while(
      notes,
      [],
      fn {_, swara, _} = note, breath ->
        case breath do
          [] ->
            {:cont, [note]}

          [{_, last, held} | _] ->
            lasted = Enum.sum(Enum.map(breath, &elem(&1, 2)))

            if not swara.glide and (swara.name == last.name or held >= longest or lasted >= 8) do
              {:cont, Enum.reverse(breath), [note]}
            else
              {:cont, [note | breath]}
            end
        end
      end,
      fn
        [] -> {:cont, []}
        breath -> {:cont, Enum.reverse(breath), []}
      end
    )
  end

  defp stretches(breath) do
    for {_, swara, beats} <- breath, do: {swara, beats}
  end

  # A pass of the oboe, given the section and how many of its passes came before; in the gat a
  # note held two beats ends a phrase.
  defp oboe(section, time) when section in [:vilambit, :drut] do
    part = gat(section, time)
    notes = for {beat, token, length} <- notes(part), do: {beat, parse(token), length}

    breaths =
      for [{beat, _, _} | _] = breath <- breaths(notes, 2) do
        vel =
          case part do
            :tihai -> Float.round(0.55 + 0.25 * beat / 16, 2)
            part when part in [:taan, :fast_taan] -> 0.6
            _ -> 0.55
          end

        {beat, breath(stretches(breath), @sa, vel)}
      end

    at(breaths, 16)
  end

  # In the alap and shanti a phrase lasts until the oboe rests.
  defp oboe(section, time) do
    section
    |> line(time)
    |> tokens()
    |> Enum.chunk_by(&(elem(&1, 0) == "-"))
    |> Enum.flat_map(fn
      [{"-", _} | _] = rests ->
        [rest(Enum.sum(Enum.map(rests, &elem(&1, 1))))]

      phrase ->
        notes = for {token, beats} <- phrase, do: {nil, parse(token), beats}
        for breath <- breaths(notes, 16), do: breath(stretches(breath), @sa, 0.5)
    end)
    |> seq()
  end

  # The oboe's ghost: the same breaths, heard only as their echo three beats later, in the alap,
  # the tihai and shanti.
  defp ghost(section, time) when section in [:alap, :shanti] or {section, time} == {:drut, 8} do
    together([oboe(section, time), desk(section, time)])
  end

  defp ghost(section, time), do: together([rest(16), desk(section, time)])

  # The oboe's echo pulls back for the gat and returns for the tihai.
  defp desk(:alap, 0), do: echo(0.5, 0)
  defp desk(:vilambit, 0), do: echo(0.2, 8)
  defp desk(:drut, 8), do: echo(0.5, 8)
  defp desk(_section, _time), do: rest(16)

  defp echo(mix, slide) do
    at([{0, change({:oboe, :ping_pong}, mix: mix, mix_slide: slide)}], 16)
  end

  # The vibraphone, its motor turning, drops two notes of the raga into each pass outside the fast
  # gat, and they bounce from side to side.
  defp stars(:drut, _time), do: rest(16)

  defp stars(section, time) do
    pass = if section == :vilambit, do: time + 1, else: time
    [first, second] = Enum.at([~w(S' P), ~w(R' M), ~w(P d), ~w(n S')], rem(pass, 4))

    at(
      [
        {5, note(swara(first, @sa + 12), 5, vel: 0.3, motor: 3)},
        {12.5, note(swara(second, @sa + 12), 3.5, vel: 0.25, motor: 3)}
      ],
      16
    )
  end

  # A plain harmonium note; on a held one the bellows ease off.
  defp harmonium_note(name, beats, vel) do
    changes = if beats >= 2, do: [{0.2, amp: 0.35, amp_slide: beats}], else: []
    note(swara(name, @sa), beats, vel: vel, sustain: beats * 0.9, release: 0.2, changes: changes)
  end

  # In the alap the harmonium answers the last three notes of the oboe's phrase while it breathes.
  defp harmonium(:alap, time) do
    tokens = tokens(line(:alap, time))
    {"-", wait} = List.last(tokens)

    names = for {token, _} <- tokens, token != "-", do: parse(token).name
    [first, second, last] = Enum.take(names, -3)

    start = 16 - wait + 0.5

    at(
      [
        {start, harmonium_note(first, 0.75, 0.45)},
        {start + 0.75, harmonium_note(second, 0.75, 0.45)},
        {start + 1.5, harmonium_note(last, wait - 2, 0.45)}
      ],
      16
    )
  end

  # In the gat it follows the composition's sthayi and antara, and leaves the taans and the tihai
  # to the oboe.
  defp harmonium(section, time) when section in [:vilambit, :drut] do
    case gat(section, time) do
      part when part in [:sthayi, :antara] ->
        notes =
          for {beat, token, length} <- notes(part),
              do: {beat, harmonium_note(parse(token).name, length, 0.35)}

        at(notes, 16)

      _ ->
        rest(16)
    end
  end

  defp harmonium(:shanti, _time), do: rest(16)

  # The pianos' figure, twelve sixteenths through the raga's ascent, d n P and g M R S.
  defp figure, do: ~w(S R g M P d n P g M R S)

  # How many passes of the gat came before, from its first.
  defp gat_pass(:vilambit, time), do: time
  defp gat_pass(:drut, time), do: 4 + time
  defp gat_pass(:shanti, time), do: 13 + time
  defp gat_pass(:alap, _time), do: nil

  defp piano_note(index, vel) do
    note(swara(Enum.at(figure(), rem(index, 12)), @sa + 12), 1,
      vel: vel,
      pedal: 1,
      sustain: 1,
      release: 0.3
    )
  end

  defp piano_vel(:shanti), do: 0.25
  defp piano_vel(_section), do: 0.32

  # The first piano keeps to the figure in sixteenths through the gat and the first pass of
  # shanti, as 64 sixteenths are a pass.
  defp piano(section, time) do
    case gat_pass(section, time) do
      pass when pass in 0..13 ->
        notes =
          for sixteenth <- 0..63,
              do: {sixteenth * 0.25, piano_note(pass * 64 + sixteenth, piano_vel(section))}

        at(notes, 16)

      _ ->
        rest(16)
    end
  end

  # The second joins on the gat's second pass, locks in for eight beats, then plays 33 notes in
  # the next eight to move a sixteenth ahead; in shanti it has come round to unison.
  defp piano_phase(section, time) do
    case gat_pass(section, time) do
      13 ->
        notes =
          for sixteenth <- 0..63,
              do: {sixteenth * 0.25, piano_note(13 * 64 + sixteenth, piano_vel(section))}

        at(notes, 16)

      pass when pass in 1..12 ->
        ahead = pass - 1

        locked =
          for sixteenth <- 0..31,
              do: {sixteenth * 0.25, piano_note(pass * 64 + ahead + sixteenth, 0.32)}

        drifting =
          for step <- 0..32,
              do:
                {Float.round(8 + step * 8 / 33, 3),
                 piano_note(pass * 64 + ahead + 32 + step, 0.32)}

        at(locked ++ drifting, 16)

      _ ->
        rest(16)
    end
  end

  # Teentaal's theka, a bol to each beat from sam, the khali, beats 9 to 12, without the bayan: a
  # dot splits a beat in two, and ~ bends the bayan up as the palm presses it.
  defp bols(:vilambit, _time) do
    "dha dhin dhin dha~  dha dhin dhin dha  na tin tin na  ta dhin dhin dha~"
  end

  defp bols(:drut, 8), do: "dha dhin dhin  ta te te dha -  ta te te dha -  ta te te"

  defp bols(:drut, _time) do
    "dha.te dhin.na dhin.na dha  dha.te dhin.na dhin.na dha~  na.te tin.na tin.na na  ta.te dhin.na dhin.na dha~"
  end

  defp bols(:shanti, 0), do: "dha" <> String.duplicate(" -", 15)

  # Each bol as the dayan's stroke and the bayan's, nil where that hand rests: dha is na over ghe,
  # and dhin is tun over ghe.
  defp strokes("dha"), do: {:tabla_na, :tabla_ghe}
  defp strokes("dhin"), do: {:tabla_tun, :tabla_ghe}
  defp strokes("tin"), do: {:tabla_tun, nil}
  defp strokes("na"), do: {:tabla_na, nil}
  defp strokes("ta"), do: {:tabla_na, nil}
  defp strokes("te"), do: {:tabla_te, nil}
  defp strokes("-"), do: {nil, nil}

  defp tabla_vel(beat, _bol) when beat == 0, do: 0.85
  defp tabla_vel(_beat, "te"), do: 0.45
  defp tabla_vel(_beat, _bol), do: 0.6

  # A pass of one tabla stroke; a bent ghe glides up two semitones as the heel presses the head.
  defp tabla(section, time, synth)
       when section in [:vilambit, :drut] or {section, time} == {:shanti, 0} do
    hits =
      for {word, beat} <- section |> bols(time) |> String.split() |> Enum.with_index(),
          halves = String.split(word, "."),
          {half, index} <- Enum.with_index(halves),
          bol = String.trim_trailing(half, "~"),
          synth in Tuple.to_list(strokes(bol)) do
        at = beat + index / length(halves)
        vel = tabla_vel(at, bol)

        if synth == :tabla_ghe and String.ends_with?(half, "~") do
          {at, hit(vel: vel, note_slide: 0.5, changes: [{0, note: 44.25}])}
        else
          {at, hit(vel: vel)}
        end
      end

    at(hits, 16)
  end

  defp tabla(_section, _time, _synth), do: rest(16)

  # The claves play son clave 3-2 through the fast gat, its eighths as sixteenths so a clave is a
  # vibhag, and in the tihai strike each landing.
  defp clave(:drut, 8) do
    hits = for beat <- [0, 0.75, 1.5, 2.5, 6, 11], do: {beat, hit(vel: 0.7)}
    at(hits, 16)
  end

  defp clave(:drut, _time), do: repeat(steps(~MX"x..x..x...x.x..."s, 0.25, vel: 0.6), 4)

  defp clave(:shanti, 0), do: at([{0, hit(vel: 0.7)}], 16)
  defp clave(_section, _time), do: rest(16)

  # The güiro scrapes slowly, whole and long, through the slow gat, plays the cha-cha-chá's down,
  # down up at double time through the fast one, and scrapes into each of the tihai's landings.
  defp guiro(:vilambit, _time) do
    hits = for beat <- 0..14//2, do: {beat, hit(vel: 0.45, sustain: 1.6)}
    at(hits, 16)
  end

  defp guiro(:drut, 8) do
    hits = for beat <- [5, 10, 15], do: {beat, hit(vel: 0.6, sustain: 0.9)}
    at(hits, 16)
  end

  defp guiro(:drut, _time) do
    hits =
      for bar <- 0..7,
          {beat, sustain, vel} <- [{0, 0.3, 0.6}, {0.5, 0.09, 0.45}, {0.75, 0.09, 0.45}],
          half <- [0, 1],
          do: {bar * 2 + half + beat, hit(vel: vel, sustain: sustain)}

    at(hits, 16)
  end

  defp guiro(_section, _time), do: rest(16)

  # The piece's length in beats, for the drones to hold through.
  defp length, do: 19 * 16

  # Each note's cents above Sa, as just intervals; a dot before a note is the octave below and a
  # quote after it the octave above.
  defp swara(token, base) do
    octave =
      cond do
        String.starts_with?(token, ".") -> -12
        String.ends_with?(token, "'") -> 12
        true -> 0
      end

    name = token |> String.trim_leading(".") |> String.trim_trailing("'")
    steps = %{"S" => 0, "R" => 204, "g" => 316, "M" => 498, "P" => 702, "d" => 814, "n" => 996}
    Float.round(base + octave + cents(steps[name]), 2)
  end
end
