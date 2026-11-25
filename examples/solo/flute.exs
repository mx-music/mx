defmodule Syrinx do
  @moduledoc """
  Debussy's Syrinx for flute alone (1913), from the first edition, Jobert, Paris, 1927, plate J.J.
  344, in the public domain.
  The score is written bar by bar as tokens: a note's sounding name and after a colon its length
  in beats, a quarter note being a beat; a note without a length keeps the one before it.
  The score's C flat is written b, its F flat e, and its double flats a and d, as they sound.
  + tongues a note, where the score starts a slur or marks it tenuto, and the others are slurred
  to; ~ ties a note into the next, ^ is a grace note, ! a fermata, r a rest, and a comma a breath.
  @0.4 moves the breath to vel 0.4, and @0.4/3 gets there over 3 beats.
  """

  use Mx.Song, tempo: 48

  part :flute, synth: :flute

  def song do
    repeat(part(:flute, flute()))
  end

  defp flute do
    {breaths, length} = breaths()
    {notes, _} = Enum.map_reduce(breaths, {0.5, 0.5, 0.0}, &breath/2)
    at(notes, Float.ceil(length) + 4)
  end

  # The breaths as lists of {beat, token}, each running from a breath mark or rest to the next,
  # and the score's length in beats.
  defp breaths do
    {breaths, current, beat} =
      Enum.reduce(tokens(), {[], [], 0.0}, fn
        {:breath, _, _, _}, {done, current, beat} ->
          {close(done, current), [], beat}

        {:rest, _, beats, _}, {done, current, beat} ->
          {close(done, current), [], beat + beats}

        {_, _, beats, _} = token, {done, current, beat} ->
          {done, [{beat, token} | current], beat + beats}
      end)

    {Enum.reverse(close(breaths, current)), beat}
  end

  # One breath as a note from its first beat: each later note is a change at its beat, a grace
  # note takes a twentieth of a beat before the note it leads to,
  # and a tongued note dips the breath to a quarter over about 30 ms and brings it back, toward
  # where a swell was heading.
  defp breath(events, {vel, target, until}) do
    [{start, _} | _] = events

    graces = graces(events)

    {changes, {_, state}} =
      events
      |> Enum.with_index()
      |> Enum.flat_map_reduce({graces, {vel, target, until}}, fn {{beat, token}, index},
                                                                 {skip, {vel, target, until}} ->
        at = Float.round(beat - start, 3)
        led = after_grace?(events, index)

        case token do
          {:vel, {to, 0}, _, _} ->
            {[{at, vel: to, vel_slide: 0.02}], {skip, {to, to, beat}}}

          {:vel, {to, over}, _, _} ->
            {[{at, vel: to, vel_slide: over}], {skip, {vel, to, beat + over}}}

          {:grace, _, _, _} when skip > 0 ->
            {[], {skip - 1, {vel, target, until}}}

          {:grace, grace, _, _} ->
            ahead =
              events
              |> Enum.drop(index)
              |> Enum.take_while(&match?({_, {:grace, _, _, _}}, &1))
              |> length()

            {[{max(at - 0.05 * ahead, 0), note: grace, note_slide: 0}],
             {skip, {vel, target, until}}}

          {:note, _, _, _} when index == 0 ->
            {[], {skip, {vel, target, until}}}

          {:note, note, _, tongued} ->
            slide = Float.round(max(until - beat, 0.025), 3)
            {attack(tongued and not led, at, note, target, slide), {skip, {vel, target, until}}}
        end
      end)

    {last_beat, {_, _, held, _}} = List.last(events)
    length = Float.round(last_beat + held - start, 3)

    changes =
      if graces > 0 do
        [{0.05 * graces, note: first_note(events), note_slide: 0} | changes]
      else
        changes
      end

    {at_start, later} = Enum.split_with(changes, fn {at, _} -> at <= 0 end)
    vel = Enum.reduce(at_start, vel, fn {_, change}, vel -> Keyword.get(change, :vel, vel) end)

    {{start,
      note(first_pitch(events), length,
        vel: vel,
        sustain: Float.round(length - 0.1, 3),
        release: 0.3,
        changes: Enum.sort_by(later, &elem(&1, 0))
      )}, state}
  end

  # Each token as {kind, value, beats, tongued}, stretched by its bar's slowing; a tie adds the
  # next note's length to the note before.
  defp tokens do
    {tokens, _} =
      score()
      |> Enum.flat_map(fn {stretch, bar} -> Enum.map(String.split(bar), &{&1, stretch}) end)
      |> Enum.map_reduce(1.0, fn {token, stretch}, last -> read(token, stretch, last) end)

    tokens
    |> List.flatten()
    |> Enum.reduce([], fn
      {:note, pitch, beats, _}, [{:tie, pitch, held, tongued} | rest] ->
        [{:note, pitch, held + beats, tongued} | rest]

      token, tokens ->
        [token | tokens]
    end)
    |> Enum.reverse()
  end

  defp close(done, []), do: done
  defp close(done, current), do: [Enum.reverse(current) | done]

  defp graces(events) do
    events
    |> Enum.take_while(fn {_, {kind, _, _, _}} -> kind in [:grace, :vel] end)
    |> Enum.count(&match?({_, {:grace, _, _, _}}, &1))
  end

  defp after_grace?(events, index) do
    index > 0 and match?({_, {:grace, _, _, _}}, Enum.at(events, index - 1))
  end

  defp attack(true, at, note, target, slide) do
    [
      {max(at - 0.025, 0), vel: target * 0.25, vel_slide: 0.02},
      {at, note: note, note_slide: 0, vel: target, vel_slide: slide}
    ]
  end

  defp attack(false, at, note, _target, _slide), do: [{at, note: note, note_slide: 0}]

  defp first_note(events) do
    Enum.find_value(events, fn {_, {kind, pitch, _, _}} -> kind == :note && pitch end)
  end

  defp first_pitch(events) do
    Enum.find_value(events, fn {_, {kind, pitch, _, _}} -> kind in [:note, :grace] && pitch end)
  end

  defp score do
    [
      {1.0, "@0.5 +bb5:3/4 a5:1/8 b5 +ab5:3/4 g5:1/8 a5 +gb5:1/4 f5 e5 db5"},
      {1.0, "+bb5:3/4 @0.4/2 c6:1/8 b5 bb5:2!,"},
      {1.0, "@0.5 +bb5:3/4 a5:1/8 b5 +ab5:3/4 g5:1/8 a5 +gb5:1/4 f5 e5 db5"},
      {1.0, "@0.35 +bb4:3/4 fs4:1/8 g4 +b4:1/2, +b4:1/6 fs4 g4 c5 fs4 g4 db5 ^f5 e5 db5"},
      {1.0, "@0.4/3 +bb4:3/4 fs4:1/8 g4 b4:1, r:1/6 +ab4 b4 db5 e5 ab5"},
      {1.0, "r:3/4 @0.6/3 +ab5:1/4 b5:2~"},
      {1.0, "b5:2 @0.45/1 db6:1"},
      {1.3, "@0.35 +eb6:2 @0.3/1 bb5:1,"},
      {0.92, "@0.35 +bb4:3/4 a4:1/8 b4 +ab4:3/4 g4:1/8 a4 +gb4:1/4 f4 e4 db4"},
      {0.92, "+bb4:3/4 @0.5/3 a4:1/8 b4 +ab4:3/4 g4:1/8 a4 +gb4:1/4 ab4 bb4 db5"},
      {0.92, "+eb5:1/4 ^gb5 f5 eb5 db5 +bb4:1, +bb4:1/4 ab4 db4 eb4"},
      {0.92, "gb4:1/8 ab4 bb4 db5 eb5 ^gb5 f5 eb5 db5 bb4:3/2, +db5:1/6 eb5 gb5"},
      {0.92, "@0.55 a5:5/8 @0.4/3 ab5:1/8 g5 gb5 +eb5:5/8 d5:1/8 db5 c5 +a4:5/8 ab4:1/8 g4 gb4"},
      {0.92, "@0.35 +eb4:1/3 ^gb4 f4 e4 eb4:1, +f4:1/2 e4"},
      {1.15, "+eb4:1/3 ^gb4 f4 e4 +eb4 ^gb4 f4 e4 +eb4 ^f4 e4 eb4"},
      {1.1, "+d4:1/3 ^f4 e4 db4 @0.45/2 c4:1/2 db4 gb4 a4"},
      {1.1, "@0.35 +d4:1/3 ^gb4 f4 d4 db4:1 @0.45/1 +db5:1,"},
      {1.1, "@0.35 +d4:1/3 ^f4 e4 db4 @0.45/2 c4:1/2 db4 gb4 a4"},
      {1.1, "@0.35 +d4:1/3 ^gb4 f4 d4 db4:1 @0.5/1 +eb5:1~"},
      {1.0, "eb5:1/2 db5:1/6 b4 bb4 ab4:1, +ab4:1/6 eb4 gb4 ab4 bb4 db5"},
      {1.0, "@0.55 +eb5:1/2 db5:1/6 eb5 f5 eb5:1/4 db5 b4 bb4:5/4,"},
      {1.0, "+bb4:1/6 b4 db5 d5 db5 b4 +bb4 b4 d5 e5 d5 b4 +bb4:1/8 a4 ab4 gb4 d4 gb4 ab4 a4"},
      {1.0, "@0.5 +bb4:1, +eb5:1/8 db5 eb5 db5 eb5 db5 eb5 db5 bb4:1"},
      {1.0, "+gb5:1/8 f5 gb5 f5 gb5 f5 gb5 f5 bb4:1 ^f5 ^gb5 ^ab5 bb5:1!~"},
      {1.0, "bb5:2, @0.55 +bb5:1~"},
      {1.0, "bb5:3/4 @0.65/3 a5:1/8 b5 +ab5:3/4 g5:1/8 a5 +gb5:1/4 f5 e5 db5,"},
      {1.0, "@0.6 +bb5:1~ bb5:1/4 db6 ^e6 d6 db6 bb5:1~"},
      {1.0, "bb5:3/4 @0.4/3 a5:1/8 b5 +ab5:3/4 g5:1/8 a5 +gb5:1/4 f5 e5 db5,"},
      {1.05, "@0.35 +bb4:1/6 a4 b4 ab4 g4 a4 gb4:1/4 f4 e4 db4,"},
      {1.1, "+bb4:1/6 a4 b4 ab4 g4 a4 gb4:1/4 f4 e4 db4~"},
      {1.2, "db4:1, @0.3/3 +db4:1/3 ^gb4 f4 e4 db4:1~"},
      {1.3, "db4:4/3 a4:1/3 g4 db4:1~"},
      {1.4, "db4:1, @0.35 +b4:2~"},
      {1.7, "b4:7/5 @0.15/4 a4:2/5 g4 f4 eb4"},
      {1.8, "^eb4 db4:3!"}
    ]
  end

  defp read("@" <> vel, _stretch, last) do
    [vel | over] = String.split(vel, "/")
    over = List.first(Enum.map(over, &String.to_integer/1), 0)
    {[{:vel, {String.to_float(vel), over}, 0, false}], last}
  end

  defp read("^" <> name, _stretch, last), do: {[{:grace, pitch(name), 0, false}], last}

  defp read(token, stretch, last) do
    [_, tongued, name, length, fermata, tie, breath] =
      Regex.run(~r/^(\+?)([a-g][sb]?\d|r)(?::([\d\/]+))?(!?)(~?)(,?)$/, token)

    beats = if length == "", do: last, else: fraction(length)
    held = beats * stretch + if(fermata == "!", do: 1.5, else: 0)

    kind =
      cond do
        name == "r" -> :rest
        tie == "~" -> :tie
        true -> :note
      end

    pitch = if name == "r", do: nil, else: pitch(name)
    breath = if breath == ",", do: [{:breath, nil, 0, false}], else: []
    {[{kind, pitch, held, tongued == "+"} | breath], beats}
  end

  defp fraction(text) do
    case String.split(text, "/") do
      [whole] -> String.to_integer(whole) / 1
      [top, bottom] -> String.to_integer(top) / String.to_integer(bottom)
    end
  end
end
