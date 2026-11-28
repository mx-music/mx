defmodule Mx.Piano do
  @moduledoc """
  What a note of mx's piano is made of, worked out from its options without playing it.

  The piano builds every note from these parts and nothing else: its strings' harmonics, each a
  resonator struck once, the partners that ring beside them, the thump of the hammer and its knock
  through the soundboard.
  Each harmonic has its `number`, 1 for the fundamental, its frequency in Hz as `hz`, its `level`
  in dB under the loudest harmonic of the note, and its `fade`, the seconds it takes to fall 60
  dB.
  Each partner has the `harmonic` it rings beside, its `kind`, `:slow` for the slow stage of that
  harmonic's fade or `:twin` for a string tuned a hair apart that beats against it, and its `hz`,
  `level` and `fade` as a harmonic's.
  The `thump` has its `level` against the loudest harmonic, the frequency its noise is filtered
  under as `below_hz`, and the `seconds` it lasts.
  The `knock` has its `level` against the loudest harmonic and the frequencies of the soundboard's
  `resonances`, or is nil when `knock` is 0.
  """

  alias Mx.Engine.Mxs.Native

  @lowest 21
  @highest 108

  @doc """
  The parts of a piano note, as `{:ok, parts}` or `{:error, message}`.

  It takes the piano's options: `note`, `vel` and `pedal`, and `aftersound`, `uneven`,
  `instrument` and `knock`, each at the piano's default unless given.
  A value outside an option's range is held to it, as when the note is played, and the parts carry
  a warning for it in `warnings`.
  A note outside the piano's keys, from A0 to C8, is refused.
  """
  def parts(options) when is_list(options) do
    note = Keyword.get(options, :note, 52)

    if note < @lowest or note > @highest do
      {:error, "the piano's keys are from A0 to C8, MIDI notes #{@lowest} to #{@highest}"}
    else
      options
      |> Enum.map(fn {name, value} -> {Atom.to_string(name), value * 1.0} end)
      |> Native.piano_parts()
      |> parts_in_db()
    end
  end

  defp kind("slow"), do: :slow
  defp kind("twin"), do: :twin

  defp parts_in_db({:error, message}), do: {:error, message}

  defp parts_in_db({:ok, {harmonics, partners, thump, knock, warnings}}) do
    loudest = harmonics |> Enum.map(&elem(&1, 2)) |> Enum.max()
    db = fn level -> 20 * :math.log10(level / loudest) end

    harmonics =
      for {number, hz, level, fade} <- harmonics do
        %{number: number, hz: hz, level: db.(level), fade: fade}
      end

    partners =
      for {harmonic, kind, hz, level, fade} <- partners do
        %{harmonic: harmonic, kind: kind(kind), hz: hz, level: db.(level), fade: fade}
      end

    {level, below_hz, seconds} = thump

    knock =
      with {level, resonances} <- knock, do: %{level: db.(level), resonances: resonances}

    {:ok,
     %{
       harmonics: harmonics,
       partners: partners,
       thump: %{level: db.(level), below_hz: below_hz, seconds: seconds},
       knock: knock,
       warnings: warnings
     }}
  end
end
