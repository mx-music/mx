defmodule Mx.Tempo do
  @moduledoc """
  The tempo over a song's beats: the timeline the band plays against, and the tempo changes a song's music writes in its sections.

  A timeline is a list of entries, the latest first, each `{beat, microseconds, tempo}`.
  The tempo is the beats per minute held from that beat, or `{:ramp, from, to, beats}`, which moves evenly in beats per minute from `from` to `to` over that many beats, and is followed by `to` held where it ends.
  A change put on the timeline replaces whatever it held from the change's beat on, so the latest change wins.

  A song's changes are `%{sections: sections, lengths: lengths, forever: forever}`: each section's changes as `{beat, bpm, over}`, each section's length in beats, and whether the music repeats until mx stops.
  Pass `n` plays section `n`, going round again in music that repeats, and a section that plays until mx stops writes its changes in its first pass only.
  """

  @doc "A timeline holding one tempo from beat 0, which plays at a real time in microseconds."
  def new(bpm, us \\ 0) when is_number(bpm) and is_integer(us), do: [{0, us, bpm}]

  @doc "The real time, in microseconds, of a beat on the timeline."
  def time_at(timeline, beat) when is_list(timeline) and is_number(beat) do
    {start, us, tempo} = Enum.find(timeline, List.last(timeline), fn {b, _, _} -> b <= beat end)
    us + elapsed_us(tempo, beat - start)
  end

  @doc "The tempo in beats per minute at a beat on the timeline."
  def tempo_at(timeline, beat) when is_list(timeline) and is_number(beat) do
    {start, _, tempo} = Enum.find(timeline, List.last(timeline), fn {b, _, _} -> b <= beat end)
    bpm(tempo, beat - start)
  end

  @doc "The beat at a real time, in microseconds, on the timeline."
  def beat_at(timeline, us) when is_list(timeline) and is_number(us) do
    {start, start_us, tempo} =
      Enum.find(timeline, List.last(timeline), fn {_, u, _} -> u <= us end)

    start + beats(tempo, us - start_us)
  end

  @doc "The timeline with the tempo changed at a beat to `bpm`, at once when `over` is 0, or else evenly over `over` beats."
  def put(timeline, beat, bpm, over)
      when is_list(timeline) and is_number(beat) and is_number(bpm) and is_number(over) do
    before =
      case Enum.drop_while(timeline, fn {b, _, _} -> b >= beat end) do
        [] -> timeline
        kept -> kept
      end

    from = tempo_at(before, beat)
    us = time_at(before, beat)
    kept = Enum.drop_while(timeline, fn {b, _, _} -> b >= beat end)

    if over == 0 or bpm == from do
      [{beat, us, bpm} | kept]
    else
      ramp = {:ramp, from, bpm, over}
      [{beat + over, us + elapsed_us(ramp, over), bpm}, {beat, us, ramp} | kept]
    end
  end

  @doc "The tempo changes a song writes in a pass, as `{beat, bpm, over}` with beats from the start of the pass."
  def changes(nil, _pass), do: []

  def changes(%{sections: sections, forever: forever}, pass) when is_integer(pass) do
    count = tuple_size(sections)
    index = if forever, do: rem(pass, count), else: pass
    if index < count, do: elem(sections, index), else: []
  end

  @doc "The timeline over beats from 0, at 0 microseconds, with the changes of every pass up to `pass` put on it, and the beat `pass` starts on; `window` is the length of each pass of a section that plays until mx stops."
  def through(tempos, bpm, pass, window \\ 0) when is_integer(pass) do
    Enum.reduce(0..pass//1, {new(bpm), 0}, fn played, {timeline, start} ->
      timeline =
        Enum.reduce(changes(tempos, played), timeline, fn {beat, bpm, over}, timeline ->
          put(timeline, start + beat, bpm, over)
        end)

      next = if played < pass, do: start + length(tempos, played, window), else: start
      {timeline, next}
    end)
  end

  defp length(nil, _pass, window), do: window

  defp length(%{lengths: lengths, forever: forever}, pass, window) do
    count = tuple_size(lengths)
    index = if forever, do: rem(pass, count), else: min(pass, count - 1)

    case elem(lengths, index) do
      :infinity -> window
      beats -> beats
    end
  end

  @doc "The tempos the timeline plays at from beat `from` until beat `until`, as text with beats counted from `from`, such as \"100 bpm, rising to 130 bpm from beat 0 to 16\"."
  def describe(timeline, from, until) when is_list(timeline) and is_number(from) do
    {ramping, ramp_end} =
      case Enum.find(timeline, List.last(timeline), fn {b, _, _} -> b <= from end) do
        {^from, _, {:ramp, start, to, over}} ->
          {["#{rising(start, to)} #{format(to)} bpm from beat 0 to #{format(over)}"],
           {from + over, to}}

        {beat, _, {:ramp, _, to, over}} when beat + over > from ->
          now = tempo_at(timeline, from)

          {["#{rising(now, to)} #{format(to)} bpm until beat #{format(beat + over - from)}"],
           {beat + over, to}}

        _ ->
          {[], nil}
      end

    {changes, _ramp_end} =
      timeline
      |> Enum.reverse()
      |> Enum.filter(fn {beat, _, _} -> beat > from and before?(beat, until) end)
      |> Enum.flat_map_reduce(ramp_end, fn
        {beat, _, {:ramp, start, to, over}}, _ ->
          {[
             "#{rising(start, to)} #{format(to)} bpm from beat #{format(beat - from)} to #{format(beat + over - from)}"
           ], {beat + over, to}}

        {beat, _, bpm}, {beat, bpm} ->
          {[], nil}

        {beat, _, bpm}, _ ->
          {["then #{format(bpm)} bpm from beat #{format(beat - from)}"], nil}
      end)

    Enum.join(["#{format(tempo_at(timeline, from))} bpm" | ramping ++ changes], ", ")
  end

  defp before?(_beat, :infinity), do: true
  defp before?(beat, until), do: beat < until

  defp rising(from, to) when to > from, do: "rising to"
  defp rising(_from, _to), do: "falling to"

  defp elapsed_us({:ramp, from, to, over}, beats) do
    round(60_000_000 * over / (to - from) * :math.log(bpm({:ramp, from, to, over}, beats) / from))
  end

  defp elapsed_us(bpm, beats), do: round(beats * 60_000_000 / bpm)

  defp bpm({:ramp, from, to, over}, beats), do: from + (to - from) * min(beats, over) / over
  defp bpm(bpm, _beats), do: bpm

  defp beats({:ramp, from, to, over}, us) do
    bpm = from * :math.exp(us * (to - from) / (60_000_000 * over))
    (bpm - from) * over / (to - from)
  end

  defp beats(bpm, us), do: us * bpm / 60_000_000

  defp format(number) when number == trunc(number), do: trunc(number)
  defp format(number), do: Float.round(number / 1, 2)
end
