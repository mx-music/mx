defmodule Mx.Voice do
  @moduledoc """
  A made-up humming voice for testing `mx.hum`, since no recording of a person humming ships with mx.

  Each note is harmonics falling 7 dB an octave, as a closed-mouth hum's do, with the faults a voice has: it scoops up into the note, wanders slowly around it, and grows vibrato once it settles.
  It also makes breaths, which are noise, and clicks, which are 3 ms bursts of noise, and a faint hiss under everything.
  The wandering and the noise are seeded, so a voice rendered twice is the same.

  Events are `{:note, at, seconds, note, opts}`, `{:breath, at, seconds}` and `{:click, at}`, with times in seconds.
  A note takes `vibrato:` in semitones either side (0.3 by default), `scoop:` in semitones below (0.6 by default), `cents:` off its pitch, and `slide_to:` with `slide_at:` and `slide:` in seconds, to glide to another note.
  """

  @doc "Renders the events over some seconds at a sample rate, as samples from -1 to 1."
  def render(events, seconds, rate) when is_list(events) and is_number(seconds) do
    :rand.seed(:exsss, {1, 2, 3})
    count = round(seconds * rate)
    silence = :array.new(count, default: 0.0)

    events
    |> Enum.reduce(silence, &add(&1, &2, rate))
    |> :array.to_list()
    |> Enum.map(&(&1 + (:rand.uniform() - 0.5) * 0.0006))
  end

  defp add({:note, at, seconds, note, opts}, sound, rate) do
    vibrato = Keyword.get(opts, :vibrato, 0.3)
    scoop = Keyword.get(opts, :scoop, 0.6)
    note = note + Keyword.get(opts, :cents, 0) / 100
    slide_to = Keyword.get(opts, :slide_to)
    slide_at = Keyword.get(opts, :slide_at, 0)
    slide = Keyword.get(opts, :slide, 0.05)
    wander = :rand.uniform() * 2 * :math.pi()
    count = round(seconds * rate)

    {samples, _} =
      Enum.map_reduce(0..(count - 1), 0.0, fn index, phase ->
        time = index / rate
        glide = if slide_to, do: (slide_to - note) * clamp((time - slide_at) / slide), else: 0
        settled = clamp((time - 0.15) / 0.2)

        pitch =
          note + glide - scoop * :math.exp(-time / 0.04) +
            vibrato * settled * :math.sin(2 * :math.pi() * 5.5 * time) +
            0.08 * :math.sin(2 * :math.pi() * 0.7 * time + wander)

        hz = 440 * 2 ** ((pitch - 69) / 12)
        phase = phase + 2 * :math.pi() * hz / rate
        envelope = clamp(time / 0.03) * clamp((seconds - time) / 0.04)
        {0.25 * envelope * harmonics(phase, hz), phase}
      end)

    place(sound, round(at * rate), samples)
  end

  defp add({:breath, at, seconds}, sound, rate) do
    count = round(seconds * rate)

    samples =
      for index <- 0..(count - 1) do
        envelope = :math.sin(:math.pi() * index / count)
        0.05 * envelope * (:rand.uniform() - 0.5)
      end

    place(sound, round(at * rate), samples)
  end

  defp add({:click, at}, sound, rate) do
    samples = for _ <- 1..round(0.003 * rate), do: 0.3 * (:rand.uniform() - 0.5)
    place(sound, round(at * rate), samples)
  end

  defp harmonics(phase, hz) do
    top = min(12, floor(3500 / hz))
    Enum.reduce(1..top//1, 0.0, fn k, sum -> sum + :math.sin(k * phase) * k ** -1.16 end)
  end

  defp place(sound, start, samples) do
    samples
    |> Enum.with_index(start)
    |> Enum.reduce(sound, fn {sample, index}, sound ->
      if index < :array.size(sound),
        do: :array.set(index, :array.get(index, sound) + sample, sound),
        else: sound
    end)
  end

  defp clamp(value), do: value |> max(0.0) |> min(1.0)
end
