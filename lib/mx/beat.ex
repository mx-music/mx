defmodule Mx.Beat do
  @moduledoc """
  Where the beat is, as a session or a render tells whoever asks to follow it.

  A message is `%{beat: beat, tempo: tempo, heard_us: heard_us}`: from `beat` on the song plays at `tempo`, and `beat` is heard at `heard_us`, a Unix time in microseconds.
  The time is when the beat leaves the output, the output's delay included; in a render it is the render's own time, which starts at 0.
  The tempo is the beats per minute held from that beat, or `{:ramp, from, to, beats}`, which moves evenly from `from` to `to` over that many beats and then holds `to`.

  `Mx.Session.follow_beat/1` sends the calling process `{:mx_beat, message}` for the tempo that holds now and for each change already known, the earliest first.
  It then sends one for each tempo change as the session learns of it, which is before its beat is heard, and for every message again whenever the output's delay moves by more than 2 ms.
  While the tempo holds and the delay is steady it sends nothing.
  When the song stops it sends `{:mx_beat, :stopped}`.
  A render sends the same messages to the process given as `follow:`.

  A message holds from its `heard_us` on, until the `heard_us` of the next one.
  A message replaces every message received before it whose beat is the same or later.
  `at/2` works out the beat at any time from the message that holds then, with no further question to mx:

      receive do
        {:mx_beat, %{} = message} -> Mx.Beat.at(message, System.os_time(:microsecond))
      end

  The beats count from where the session started playing, as the beat `Mx.Band.beat_at/2` answers with does.
  """

  @minute_us 60_000_000

  @doc "The beat heard at the Unix time `us`, in microseconds, by a message."
  def at(%{beat: beat, tempo: tempo, heard_us: heard_us}, us) when is_number(us) do
    beat + beats(tempo, us - heard_us)
  end

  @doc "The Unix time in microseconds at which `beat` is heard, by a message."
  def heard_at(%{beat: start, tempo: tempo, heard_us: heard_us}, beat) when is_number(beat) do
    heard_us + round(elapsed_us(tempo, beat - start))
  end

  @doc "The messages of a timeline, as `Mx.Tempo` keeps it, from the one that holds at `now_us` on, the earliest first, each heard `delay_us` after its time on the timeline."
  def messages(timeline, delay_us, now_us)
      when is_list(timeline) and is_integer(delay_us) and is_integer(now_us) do
    {messages, _ramp_end} =
      timeline
      |> Enum.reverse()
      |> Enum.reduce({[], nil}, fn
        # A ramp is followed on the timeline by the tempo it ends at, which its message already
        # holds.
        {beat, _us, bpm}, {messages, {beat, bpm}} ->
          {messages, nil}

        {beat, us, {:ramp, _from, to, over} = ramp}, {messages, _ramp_end} ->
          {[%{beat: beat, tempo: ramp, heard_us: us + delay_us} | messages], {beat + over, to}}

        {beat, us, bpm}, {messages, _ramp_end} ->
          {[%{beat: beat, tempo: bpm, heard_us: us + delay_us} | messages], nil}
      end)

    messages |> Enum.reverse() |> holding(now_us)
  end

  defp holding([_past, %{heard_us: heard_us} = next | rest], now_us) when heard_us <= now_us do
    holding([next | rest], now_us)
  end

  defp holding(messages, _now_us), do: messages

  defp beats({:ramp, from, _to, _over}, us) when us < 0, do: us * from / @minute_us

  defp beats({:ramp, from, to, over} = ramp, us) do
    ramp_us = elapsed_us(ramp, over)

    if us >= ramp_us do
      over + (us - ramp_us) * to / @minute_us
    else
      bpm = from * :math.exp(us * (to - from) / (@minute_us * over))
      (bpm - from) * over / (to - from)
    end
  end

  defp beats(bpm, us), do: us * bpm / @minute_us

  defp elapsed_us({:ramp, from, _to, _over}, beats) when beats < 0 do
    beats * @minute_us / from
  end

  defp elapsed_us({:ramp, from, to, over}, beats) when beats <= over do
    bpm = from + (to - from) * beats / over
    @minute_us * over / (to - from) * :math.log(bpm / from)
  end

  defp elapsed_us({:ramp, _from, to, over} = ramp, beats) do
    elapsed_us(ramp, over) + (beats - over) * @minute_us / to
  end

  defp elapsed_us(bpm, beats), do: beats * @minute_us / bpm
end
