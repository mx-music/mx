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
    if File.exists?(path), do: {:ok, path}, else: {:error, "sample file #{file} does not exist"}
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
