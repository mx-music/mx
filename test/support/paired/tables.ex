defmodule Mx.Paired.Tables do
  @moduledoc """
  mxs's struck voices that play a table fitted to recordings, written with defsynth:
  `use Mx.Paired.Tables` with a synth's name, how it plays its table, its level, its default note
  and its release.
  """

  defmacro __using__(opts) do
    name = opts[:name]
    {play, level, growth} = {opts[:play], opts[:level], opts[:growth] || 1}

    quote do
      use Mx.Instrument

      @doc "A struck note played from mxs's table fitted to its recordings."
      attr :note, :note, default: unquote(opts[:note]), doc: "The pitch."
      attr :vel, :float, default: 0.6, range: 0..1, doc: "How hard it is struck."
      envelope_attrs sustain: 1000, release: unquote(opts[:release])
      attr :bend, :float, default: 0, doc: "Semitones the pitch is bent by."

      attr :brightness, :float,
        default: 0.5,
        range: 0..1,
        doc: "Tilts the sound 3 dB an octave either way of 0.5."

      defsynth unquote(name)(_o) do
        figures(unquote(name),
          play: unquote(play),
          level: unquote(level),
          growth: unquote(growth)
        )
      end
    end
  end
end
