defmodule Mix.Tasks.Mx.Fit do
  @shortdoc "Searches for the values of a synth's controls that match recordings of held notes"

  @moduledoc """
  Searches for the values of a synth's controls that bring its held notes closest to recordings of them, as `Mx.Fit` describes.

      mix mx.fit clarinet --vel 0.3 BbClar.pp.D3B3.aiff:D3 BbClar.pp.C4B4.aiff:C4 --vel 1 BbClar.ff.D3B3.aiff:D3 --from 160 --control k_odd=-2:2 --control k_att=0.15:x1.15

  The synth comes first, then each dynamic as `--vel` and the files played at it, each with the note it starts on, as `mix mx.measure` takes them.
  `--control` gives a control the synth takes, its starting value and its step, such as `k_odd=-2:2`; a step written with an x, such as `x1.15`, multiplies and divides instead of adding and subtracting.
  `--from` gives the lowest frequency in Hz of the bands compared, all of them below 4 kHz unless given.
  It prints how many notes it kept at each dynamic and how many it left out, the score it starts from, each change it keeps, and the best values at the end.
  `--drone` measures each file as one note held from its first sample to its last, for a drone plucked again and again, which would otherwise read as a note at each pluck, and leaves out the attack.
  `--check` scores the starting values instead of searching, and needs no control; it prints each dynamic's attack difference, and each band's level of harmonics and of noise in the recordings and how far the synth is off, marking those beyond 30 percent or 6 dB.
  The recordings' figures are kept in the system's temporary folder and reused until a file changes.
  """

  use Mix.Task

  alias Mx.{Fit, Measure, Notes, Synths}

  @example "BbClar.pp.D3B3.aiff:D3"

  @impl true
  def run(args) when is_list(args) do
    Mix.Task.run("app.config")
    {synth, rest} = synth!(args)
    parsed = parse!(rest, %{dynamics: [], controls: [], from: 0, check: false, drone: false})

    dynamics =
      Enum.reverse(parsed.dynamics) |> Enum.map(fn {vel, files} -> {vel, Enum.reverse(files)} end)

    controls = parsed.controls |> Enum.reverse() |> Enum.map(&control!(synth, &1))

    if dynamics == [] do
      Mix.raise("give each dynamic as --vel and its files, such as --vel 0.3 #{@example}")
    end

    if controls == [] and not parsed.check do
      Mix.raise("give each control to fit, such as --control k_odd=-2:2")
    end

    recorded = recordings!(dynamics, parsed.drone)
    lowest = Fit.lowest(dynamics)
    highest = recorded |> Enum.map(& &1.highest) |> Enum.max()
    notes = Enum.to_list(lowest..highest)
    values = for control <- controls, do: {control.name, control.value}

    if parsed.check do
      check(synth, recorded, notes, parsed.from, values)
    else
      {best, score} = Fit.search(synth, recorded, notes, parsed.from, controls, &report/1)

      IO.puts(
        "best #{decimals(score)}: " <>
          Enum.map_join(best, " ", fn {name, value} -> "#{name}=#{number(value)}" end)
      )
    end
  end

  defp recordings!(dynamics, drone) do
    case Fit.recordings(dynamics, drone) do
      {:error, message} ->
        Mix.raise(message)

      {:ok, recorded, cached} ->
        if cached, do: IO.puts("using the recordings' figures from an earlier run")

        for dynamic <- recorded do
          below = "#{dynamic.below} below #{Measure.name(Fit.lowest(dynamics))}"

          IO.puts(
            "vel #{number(dynamic.vel)}: #{dynamic.notes} notes, left out #{dynamic.quiet} quiet stretches and #{below}"
          )
        end

        recorded
    end
  end

  defp check(synth, recorded, notes, from, values) do
    misses = Fit.misses(synth, recorded, notes, from, values)

    for %{vel: vel, attack: attack, bands: bands, noise: noise} <- misses do
      IO.puts("vel #{number(vel)} attack #{attack(attack)}")

      for {kind, rows} <- [{"", bands}, {" noise", noise}],
          {{low, high}, level, difference} <- rows do
        flag = if abs(difference) > 6, do: " <--", else: ""
        recorded = signed_decimals(level)
        missed = signed_decimals(difference)

        IO.puts(
          "vel #{number(vel)} #{low}-#{high} Hz#{kind} recordings #{recorded} dB, off by #{missed} dB#{flag}"
        )
      end
    end

    IO.puts("score #{decimals(Fit.score(misses))}")
  end

  defp attack(nil), do: "-"

  defp attack(attack) do
    percent = signed(round(attack * 100))
    flag = if abs(attack) > 0.3, do: " <--", else: ""
    "#{percent}%#{flag}"
  end

  defp report({:start, score}), do: IO.puts("start #{decimals(score)}")
  defp report({:round, round}), do: IO.puts("round #{round}")

  defp report({:kept, name, value, score}) do
    IO.puts("  #{name} #{number(value)}: #{decimals(score)}")
  end

  defp synth!([name | rest]) do
    if String.starts_with?(name, "--") do
      Mix.raise("give the synth first, such as mix mx.fit clarinet")
    end

    {Enum.find(Synths.synths(), &(Atom.to_string(&1) == name)) ||
       Mix.raise("unknown synth #{name}"), rest}
  end

  defp synth!([]), do: Mix.raise("give the synth first, such as mix mx.fit clarinet")

  defp parse!([], parsed), do: parsed

  defp parse!(["--vel", text | rest], parsed) do
    parse!(rest, %{parsed | dynamics: [{float!(text, "--vel"), []} | parsed.dynamics]})
  end

  defp parse!(["--from", text | rest], parsed) do
    parse!(rest, %{parsed | from: float!(text, "--from")})
  end

  defp parse!(["--control", text | rest], parsed) do
    parse!(rest, %{parsed | controls: [text | parsed.controls]})
  end

  defp parse!(["--check" | rest], parsed), do: parse!(rest, %{parsed | check: true})
  defp parse!(["--drone" | rest], parsed), do: parse!(rest, %{parsed | drone: true})
  defp parse!(["--" <> _ = flag | _rest], _parsed), do: Mix.raise("unknown option #{flag}")

  defp parse!([file | rest], %{dynamics: [{vel, files} | dynamics]} = parsed) do
    parse!(rest, %{parsed | dynamics: [{vel, [file!(file) | files]} | dynamics]})
  end

  defp parse!([_file | _rest], _parsed) do
    Mix.raise("give --vel before its files, such as --vel 0.3 #{@example}")
  end

  defp file!(arg) do
    case Regex.run(~r/^(.+):([^:]+)$/, arg) do
      [_, path, note] -> {path, note!(note)}
      nil -> Mix.raise("give each file with the note it starts on, such as #{@example}")
    end
  end

  defp note!(text) do
    Notes.from_text(text)
  rescue
    ArgumentError -> Mix.raise("unknown note #{text}")
  end

  defp control!(synth, text) do
    with [name, value, step] <- String.split(text, ["=", ":"]),
         {value, ""} <- Float.parse(value),
         {ratio, step} = ratio(step),
         {step, ""} <- Float.parse(step) do
      %{name: option!(synth, name), value: value, step: step, ratio: ratio}
    else
      _other ->
        Mix.raise(
          "give --control as a name, a starting value and a step, such as --control k_odd=-2:2"
        )
    end
  end

  defp ratio("x" <> step), do: {true, step}
  defp ratio(step), do: {false, step}

  # Every control a synth takes is already an atom, so a name that is not one is no control.
  defp option!(synth, name) do
    option =
      try do
        String.to_existing_atom(name)
      rescue
        ArgumentError -> nil
      end

    if option && Synths.option?(synth, option) do
      option
    else
      Mix.raise("#{synth} takes no control #{name}")
    end
  end

  defp float!(text, flag) do
    case Float.parse(text) do
      {value, ""} -> value
      _other -> Mix.raise("#{flag} takes a number, not #{text}")
    end
  end

  defp number(value) when value == trunc(value), do: Integer.to_string(trunc(value))
  defp number(value), do: value |> Float.round(4) |> Float.to_string()

  defp decimals(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)
  defp signed_decimals(value) when value >= 0, do: "+" <> decimals(value)
  defp signed_decimals(value), do: decimals(value)
  defp signed(value) when value >= 0, do: "+#{value}"
  defp signed(value), do: "#{value}"
end
