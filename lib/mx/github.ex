defmodule Mx.GitHub do
  @moduledoc """
  Files of public GitHub repositories, downloaded into the user's cache, for samples a song names as `{collection, path}` or `{:github, repo, ref, path}` and collections downloaded ahead of time.

  Each repository and ref has its own folder in the cache, so two refs of one repository never share a file.
  A file is written under a temporary name and renamed once complete, so an interrupted download never leaves a file that looks downloaded.
  Files come from GitHub's raw file server, and a folder's files are listed with GitHub's API, which limits requests without a login.
  """

  @doc "The folder GitHub files are cached in: the `:github_dir` setting, or a folder in the user's cache."
  def dir do
    Application.get_env(
      :mx,
      :github_dir,
      Path.join(:filename.basedir(:user_cache, "mx"), "github")
    )
  end

  @doc "Where a file of a repository at a ref is kept in the cache."
  def local(repo, ref, path), do: Path.join([dir(), repo, URI.encode_www_form(ref), path])

  @doc "Downloads a file of a repository at a ref into the cache, and returns `:ok` or `{:error, reason}`."
  def fetch(repo, ref, path) do
    local = local(repo, ref, path)
    File.mkdir_p!(Path.dirname(local))
    url = Enum.join([raw_url(), repo, encode(ref), encode(path)], "/")

    case request(url, stream: String.to_charlist(local <> ".part")) do
      {:ok, :saved_to_file} ->
        File.rename!(local <> ".part", local)

      {:ok, {{_, 404, _}, _, _}} ->
        {:error, "the file is not in #{repo} at #{ref}"}

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "GitHub answered #{status}"}

      {:error, reason} ->
        {:error, reason(reason)}
    end
    |> tap(fn result -> if result != :ok, do: File.rm(local <> ".part") end)
  end

  @doc "The paths of the files in a folder of a repository at a ref, or in the whole repository for nil, as `{:ok, paths}` or `{:error, message}`."
  def list(repo, ref, folder) do
    case api("/repos/#{repo}/git/trees/#{encode(ref)}?recursive=1") do
      {:ok, %{"tree" => tree}} ->
        prefix = if folder, do: String.trim_trailing(folder, "/") <> "/", else: ""

        paths =
          for %{"type" => "blob", "path" => path} <- tree,
              String.starts_with?(path, prefix),
              do: path

        case paths do
          [] -> {:error, "#{repo} has no folder #{folder} at #{ref}"}
          paths -> {:ok, paths}
        end

      {:error, status} when status in [404, 422] ->
        case api("/repos/#{repo}") do
          {:error, 404} -> {:error, "GitHub has no public repository #{repo}"}
          {:error, message} when is_binary(message) -> {:error, message}
          _ -> {:error, "#{repo} has no ref #{ref}"}
        end

      {:error, status} when is_integer(status) ->
        {:error, "GitHub answered #{status} when listing #{repo} at #{ref}"}

      {:error, message} ->
        {:error, message}
    end
  end

  defp api(path) do
    case request(api_url() <> path, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, JSON.decode!(body)}

      {:ok, {{_, status, _}, headers, _body}} when status in [403, 429] ->
        headers = Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)

        if headers["x-ratelimit-remaining"] == "0" do
          resets =
            headers["x-ratelimit-reset"]
            |> String.to_integer()
            |> DateTime.from_unix!()
            |> Calendar.strftime("%Y-%m-%d %H:%M UTC")

          {:error,
           "GitHub's limit of requests without a login is reached; it resets at #{resets}"}
        else
          {:error, status}
        end

      {:ok, {{_, status, _}, _headers, _body}} ->
        {:error, status}

      {:error, reason} ->
        {:error, "cannot reach GitHub: #{reason(reason)}"}
    end
  end

  defp request(url, opts) do
    {:ok, _} = Application.ensure_all_started([:inets, :ssl])

    ssl = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 3,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    headers = [{~c"user-agent", ~c"mx"}]
    :httpc.request(:get, {String.to_charlist(url), headers}, [ssl: ssl, timeout: 60_000], opts)
  end

  defp reason({:failed_connect, _}), do: "cannot connect to GitHub"
  defp reason(reason), do: inspect(reason)

  defp encode(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
  end

  defp raw_url, do: Application.get_env(:mx, :github_raw_url, "https://raw.githubusercontent.com")
  defp api_url, do: Application.get_env(:mx, :github_api_url, "https://api.github.com")
end
