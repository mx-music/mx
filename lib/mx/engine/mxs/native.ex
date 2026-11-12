defmodule Mx.Engine.Mxs.Native do
  @moduledoc false

  use Rustler, otp_app: :mx, crate: "mxs_nif"

  def start(_live, _input), do: :erlang.nif_error(:nif_not_loaded)
  def catalog, do: :erlang.nif_error(:nif_not_loaded)
  def now(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def seconds_at(_engine, _unix_us), do: :erlang.nif_error(:nif_not_loaded)
  def register_graph(_engine, _name, _specs, _clauses), do: :erlang.nif_error(:nif_not_loaded)

  def register_effect_graph(_engine, _name, _specs, _graph) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def rate(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def inputs(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def play(_engine, _events), do: :erlang.nif_error(:nif_not_loaded)
  def load_sample(_engine, _path), do: :erlang.nif_error(:nif_not_loaded)
  def check_sample(_path), do: :erlang.nif_error(:nif_not_loaded)
  def sample_peak(_path), do: :erlang.nif_error(:nif_not_loaded)

  def pitches(_samples, _rate, _lowest, _highest, _frame, _hop) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def start_effects(_engine, _effects), do: :erlang.nif_error(:nif_not_loaded)
  def stop_effects(_engine, _chain, _at), do: :erlang.nif_error(:nif_not_loaded)
  def render(_engine, _seconds), do: :erlang.nif_error(:nif_not_loaded)
  def record(_engine, _path, _source, _at), do: :erlang.nif_error(:nif_not_loaded)
  def stop_recording(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def record_output(_engine, _path, _at), do: :erlang.nif_error(:nif_not_loaded)
  def stop_recording_output(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def sounding(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def warnings(_engine), do: :erlang.nif_error(:nif_not_loaded)
  def panic_on_purpose, do: :erlang.nif_error(:nif_not_loaded)
end
