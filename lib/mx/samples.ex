defmodule Mx.Samples do
  @moduledoc """
  Sonic Pi's sample pack, which is under Creative Commons 0, and the files a song plays as samples: a file by path, a file of a collection as `{collection, name}`, or a file of any public GitHub repository as `{:github, repo, ref, path}`.

  `Mx.Collections` lists the collections: `{:sonic_pi, :loop_amen}` is a sample of the pack, and `{:vcsl, path}` a file of a repository mx knows by name.

  The pack is too large for the repository, so `download/1` fetches it from a fixed Sonic Pi release into a folder outside the repository, the user's cache by default.
  Each file is written under a temporary name and renamed once complete, so an interrupted download never leaves a sample that looks downloaded.
  """

  alias Mx.Collections
  alias Mx.Engine.Mxs.Native

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

  @doc "How messages name a sample: by its name in the pack, its path, its collection and path, or its repository and path."
  def name({:github, repo, _ref, path}), do: "#{repo} #{path}"
  def name({:sonic_pi, name}), do: to_string(name)
  def name({collection, path}), do: "#{collection} #{path}"
  def name(ref), do: to_string(ref)

  @doc "Refuses a GitHub sample's reference that is not `{:github, \"owner/repo\", ref, path}`, as `:ok` or `{:error, message}`."
  def check_github({:github, repo, ref, path} = github) do
    if is_binary(repo) and repo =~ ~r"^[\w.-]+/[\w.-]+$" and is_binary(ref) and ref != "" and
         is_binary(path) and path != "" do
      :ok
    else
      github = inspect(github)
      {:error, "a GitHub sample is {:github, \"owner/repo\", ref, path}, not #{github}"}
    end
  end

  @doc "Refuses a sample's reference that mx cannot read, as `:ok` or `{:error, message}`, without looking for its file."
  def check_ref({:github, _repo, _ref, _path} = github), do: check_github(github)
  def check_ref({:sonic_pi, name}) when is_atom(name), do: :ok
  def check_ref(path) when is_binary(path), do: :ok

  def check_ref(name) when is_atom(name) do
    name = inspect(name)
    {:error, "sample #{name} needs its collection, as {:sonic_pi, #{name}}"}
  end

  def check_ref(ref) do
    if Collections.ref?(ref) and elem(ref, 0) != :sonic_pi do
      with {:ok, _github} <- Collections.expand(ref), do: :ok
    else
      ref = inspect(ref)

      {:error,
       "sample takes a path, {collection, name} or {:github, repo, ref, path}, not #{ref}"}
    end
  end

  @doc "The full path of a sample given as a file path, of a collection, or of a GitHub repository, downloaded into the cache when it is not there yet, or `{:error, message}` saying why it cannot play."
  def path(ref, dir \\ dir())

  def path({:github, repo, ref, file} = github, _dir) do
    local = Mx.GitHub.local(repo, ref, file)

    with :ok <- check_github(github),
         :ok <- if(File.exists?(local), do: :ok, else: download_one(repo, ref, file)) do
      path(local, nil)
    end
  end

  def path({:sonic_pi, name}, dir) when is_atom(name) and is_binary(dir) do
    file = "#{name}.flac"
    path = Path.expand(file, dir)

    cond do
      file not in names() ->
        {:error, "unknown sample #{name}"}

      File.exists?(path) ->
        {:ok, path}

      true ->
        {:error,
         "sample #{name} is in Sonic Pi's sample pack, which is not downloaded yet; run mix mx.samples.download sonic_pi"}
    end
  end

  def path(file, _dir) when is_binary(file) do
    path = Path.expand(file)

    if File.exists?(path) do
      case Native.check_sample(path) do
        {:ok, _seconds} -> {:ok, path}
        {:error, reason} -> {:error, "sample file #{file} cannot play: #{reason}"}
      end
    else
      {:error, "sample file #{file} does not exist"}
    end
  end

  def path(ref, dir) do
    with :ok <- check_ref(ref),
         {:ok, github} <- Collections.expand(ref) do
      path(github, dir)
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

      true ->
        check_slices(ref, path, opts, given)
    end
  end

  defp check_slices(ref, path, opts, given) do
    cond do
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
        ref = name(ref)
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
        if beats = opts[:beats] do
          cut ++ [rate: abs(finish - start) * seconds * tempo / (60 * beats)]
        else
          cut
        end

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

  @doc "The loudest moment of a sample file mx can play, as a level from 0, read from the whole file."
  def peak(path) when is_binary(path) do
    {:ok, peak} = Native.sample_peak(path)
    peak
  end

  @doc "The line mx prints when the song loads for a sample file played at `peak`, silent or too quiet to hear without normalize, or nil."
  def level_warning(ref, peak, normalized?)

  def level_warning(ref, peak, _normalized?) when peak == 0, do: "sample #{name(ref)} is silent"

  def level_warning(ref, peak, false) do
    below = -20 * :math.log10(peak)

    if below > 40 do
      below = :erlang.float_to_binary(below, decimals: 1)
      ref = name(ref)
      "sample #{ref} peaks #{below} dB below full scale; normalize: true plays it at full scale"
    end
  end

  def level_warning(_ref, _peak, true), do: nil

  @doc "The length in seconds of a sample file mx can play."
  def seconds(path) when is_binary(path) do
    {:ok, seconds} = Native.check_sample(path)
    seconds
  end

  defp download_one(repo, ref, file) do
    IO.puts("Downloading #{file} from #{repo} at #{ref}")

    case Mx.GitHub.fetch(repo, ref, file) do
      :ok -> :ok
      {:error, reason} -> {:error, "cannot download sample #{file} from #{repo}: #{reason}"}
    end
  end

  @doc """
  Downloads a collection ahead of time, for `mx samples download SOURCE` and `mix mx.samples.download SOURCE`, and returns `{:ok, message}` or `{:error, message}`.

  SOURCE is a collection's name, such as `sonic_pi` or `vcsl`, or a GitHub repository as `owner/repo@ref`; but for `sonic_pi`, either is optionally followed by `:folder` for only that folder.
  Files already on disk are skipped, so running it again finishes an interrupted download.
  """
  def download_source("sonic_pi") do
    dir = dir()

    case download(dir: dir) do
      {:ok, 0} ->
        {:ok, "Sonic Pi's sample pack is complete in #{dir}."}

      {:ok, count} ->
        {:ok, "Downloaded #{count} files to #{dir}, and Sonic Pi's sample pack is complete."}

      {:error, file, reason, count} ->
        {:error, failed(file, reason, count, dir, "sonic_pi")}
    end
  end

  def download_source(source) when is_binary(source) do
    [name | folder] = String.split(source, ":", parts: 2)
    collection = Enum.find(Collections.names(), &(to_string(&1) == name))

    case {collection && Collections.github(collection), github_source(source)} do
      {{repo, commit}, _} ->
        download_github(source, repo, commit, List.first(folder))

      {nil, [repo, ref | folder]} ->
        download_github(source, repo, ref, List.first(folder))

      {nil, nil} ->
        names = Enum.join(Collections.names(), ", ")

        {:error,
         "SOURCE is a collection, one of #{names}, or a GitHub repository as owner/repo@ref, optionally followed by :folder, not #{source}"}
    end
  end

  defp github_source(source) do
    case Regex.run(~r"^([\w.-]+/[\w.-]+)@([^:]+)(?::(.+))?$", source) do
      [_ | parts] -> parts
      nil -> nil
    end
  end

  defp download_github(source, repo, ref, folder) do
    dir = Path.dirname(Mx.GitHub.local(repo, ref, "file"))

    with {:ok, files} <- Mx.GitHub.list(repo, ref, folder) do
      result =
        Enum.reduce_while(files, {:ok, 0}, fn file, {:ok, count} ->
          if File.exists?(Mx.GitHub.local(repo, ref, file)) do
            {:cont, {:ok, count}}
          else
            case Mx.GitHub.fetch(repo, ref, file) do
              :ok -> {:cont, {:ok, count + 1}}
              {:error, reason} -> {:halt, {:error, file, reason, count}}
            end
          end
        end)

      case result do
        {:ok, 0} -> {:ok, "#{source} is complete in #{dir}."}
        {:ok, count} -> {:ok, "Downloaded #{count} files to #{dir}, and #{source} is complete."}
        {:error, file, reason, count} -> {:error, failed(file, reason, count, dir, source)}
      end
    end
  end

  defp failed(file, reason, count, dir, source) do
    "Could not download #{file}: #{reason}.\nThe #{count} files downloaded before it stay in #{dir}; run mix mx.samples.download #{source} again to finish."
  end

  @doc "Downloads the files of the pack that are missing, with its licence, and returns `{:ok, count}` or `{:error, file, reason, count}`."
  def download(opts \\ []) when is_list(opts) do
    dir = Keyword.get(opts, :dir, dir())
    base_url = Keyword.get(opts, :base_url, Application.get_env(:mx, :samples_url, @base_url))
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
