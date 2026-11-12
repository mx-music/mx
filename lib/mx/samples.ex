defmodule Mx.Samples do
  @moduledoc """
  Sonic Pi's sample pack, which is under Creative Commons 0, and the files a song plays as samples.

  The pack is too large for the repository, so `download/1` fetches it from a fixed Sonic Pi release into a folder outside the repository, the user's cache by default.
  Each file is written under a temporary name and renamed once complete, so an interrupted download never leaves a sample that looks downloaded.
  """

  @release "v5.0.0"
  @base_url "https://raw.githubusercontent.com/sonic-pi-net/sonic-pi/#{@release}/etc/samples"
  @licence "README.md"

  @doc "The names of the files in Sonic Pi's sample pack, without their extension."
  def names do
    Application.app_dir(:mx, "priv/samples.txt") |> File.read!() |> String.split("\n", trim: true)
  end

  @doc "The folder the sample pack is in: the `:samples_dir` setting, or `default_dir/0`."
  def dir, do: Application.get_env(:mx, :samples_dir, default_dir())

  @doc "The folder in the user's cache the sample pack downloads to."
  def default_dir, do: Path.join(:filename.basedir(:user_cache, "mx"), "samples-#{@release}")

  @doc "The full path of a sample named as an atom from the pack, or given as a file path, or `{:error, message}` saying why it cannot play."
  def path(ref, dir \\ dir())

  def path(name, dir) when is_atom(name) and is_binary(dir) do
    file = "#{name}.flac"
    path = Path.expand(file, dir)

    cond do
      file not in names() ->
        {:error, "unknown sample #{name}"}

      File.exists?(path) ->
        {:ok, path}

      true ->
        {:error,
         "sample #{name} is in Sonic Pi's sample pack, which is not downloaded yet; run mix mx.samples"}
    end
  end

  def path(file, dir) when is_binary(file) and is_binary(dir) do
    path = Path.expand(file)

    if File.exists?(path) do
      case Mx.Engine.Mxs.Native.check_sample(path) do
        {:ok, _seconds} -> {:ok, path}
        {:error, reason} -> {:error, "sample file #{file} cannot play: #{reason}"}
      end
    else
      {:error, "sample file #{file} does not exist"}
    end
  end

  @cut [:from, :to, :beats, :slices, :slice]

  @doc "Whether an option cuts a sample or fits it to beats, which mx works out into the sample players' own options."
  def cut_option?(option), do: option in @cut

  @doc "Refuses options that cannot cut the sample `ref` at `path`, as `:ok` or `{:error, message}`."
  def check_cut(ref, path, opts) do
    given = &Keyword.has_key?(opts, &1)

    cond do
      fraction = Enum.find([:start, :finish], &(given.(&1) and not fraction?(opts[&1]))) ->
        value = opts[fraction]
        {:error, "a sample's #{fraction} takes a fraction of the file from 0 to 1, not #{value}"}

      Enum.any?([:start, :finish], given) and Enum.any?([:from, :to], given) ->
        {:error, "a sample takes start and finish, or from and to, not both"}

      given.(:beats) and given.(:rate) ->
        {:error, "a sample takes beats or rate, not both"}

      given.(:beats) and not (is_number(opts[:beats]) and opts[:beats] > 0) ->
        beats = opts[:beats]
        {:error, "a sample's beats takes a number above 0, not #{beats}"}

      given.(:slices) != given.(:slice) ->
        {:error, "a sample takes slices and slice together"}

      given.(:slices) and not (is_integer(opts[:slices]) and opts[:slices] > 0) ->
        slices = opts[:slices]
        {:error, "a sample's slices takes a whole number above 0, not #{slices}"}

      given.(:slice) and
          not (is_integer(opts[:slice]) and opts[:slice] in 0..(opts[:slices] - 1)//1) ->
        slice = opts[:slice]
        last = opts[:slices] - 1
        {:error, "a sample's slice takes a whole number from 0 to #{last}, not #{slice}"}

      Enum.any?([:from, :to], given) ->
        check_seconds(ref, seconds(path), Keyword.take(opts, [:from, :to]))

      true ->
        :ok
    end
  end

  defp fraction?(value), do: is_number(value) and value >= 0 and value <= 1

  defp check_seconds(ref, seconds, given) do
    case Enum.find(given, fn {_, at} -> not (is_number(at) and at >= 0 and at <= seconds) end) do
      nil ->
        :ok

      {option, at} ->
        length = :erlang.float_to_binary(seconds, decimals: 3)
        {:error, "sample #{ref} lasts #{length} seconds, so #{option}: #{at} is outside it"}
    end
  end

  @doc "Sample options with from, to, slices, slice and beats worked out into start, finish and rate, for a file of `seconds` played at `tempo`; options that cut nothing need no length."
  def cut(opts, seconds, tempo) when is_list(opts) and is_number(tempo) do
    if Enum.any?(@cut, &Keyword.has_key?(opts, &1)) do
      start = if from = opts[:from], do: from / seconds, else: Keyword.get(opts, :start, 0)
      finish = if to = opts[:to], do: to / seconds, else: Keyword.get(opts, :finish, 1)
      {start, finish} = slice(start, finish, opts[:slices], opts[:slice])
      cut = [start: start, finish: finish]

      cut =
        if beats = opts[:beats],
          do: cut ++ [rate: abs(finish - start) * seconds * tempo / (60 * beats)],
          else: cut

      Keyword.drop(opts, @cut ++ [:start, :finish]) ++ cut
    else
      opts
    end
  end

  defp slice(start, finish, nil, nil), do: {start, finish}

  defp slice(start, finish, slices, slice) do
    piece = (finish - start) / slices
    {start + piece * slice, start + piece * (slice + 1)}
  end

  @doc "The length in seconds of a sample file mx can play."
  def seconds(path) when is_binary(path) do
    {:ok, seconds} = Mx.Engine.Mxs.Native.check_sample(path)
    seconds
  end

  @doc "Downloads the files of the pack that are missing, with its licence, and returns `{:ok, count}` or `{:error, file, reason, count}`."
  def download(opts \\ []) when is_list(opts) do
    dir = Keyword.get(opts, :dir, dir())
    base_url = Keyword.get(opts, :base_url, @base_url)
    files = Keyword.get_lazy(opts, :names, &names/0) ++ [@licence]
    File.mkdir_p!(dir)
    {:ok, _} = Application.ensure_all_started([:inets, :ssl])

    Enum.reduce_while(files, {:ok, 0}, fn file, {:ok, count} ->
      path = Path.join(dir, file)

      if File.exists?(path) do
        {:cont, {:ok, count}}
      else
        case fetch(base_url <> "/" <> file, path) do
          :ok -> {:cont, {:ok, count + 1}}
          {:error, reason} -> {:halt, {:error, file, reason, count}}
        end
      end
    end)
  end

  defp fetch(url, path) do
    part = path <> ".part"

    ssl = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 3,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    http_opts = [ssl: ssl, timeout: 60_000]

    case :httpc.request(:get, {String.to_charlist(url), []}, http_opts,
           stream: String.to_charlist(part)
         ) do
      {:ok, :saved_to_file} ->
        File.rename!(part, path)

      {:ok, {{_, status, _}, _, _}} ->
        File.rm(part)
        {:error, "the server answered #{status}"}

      {:error, reason} ->
        File.rm(part)
        {:error, inspect(reason)}
    end
  end
end
