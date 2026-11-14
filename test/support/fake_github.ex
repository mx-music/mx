defmodule Mx.FakeGitHub do
  @moduledoc """
  A local server answering as GitHub's raw file server and API do, for testing downloads without the network.

  `start/1` takes each repository's refs, each a map of paths to contents, where `:fail` answers 500 for that file.
  The `:limited` option answers every API request as GitHub does once its limit of requests without a login is reached.
  It sets mx's GitHub settings to the server and a cache folder, and puts them back when the test exits.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]
  require Record

  Record.defrecordp(:mod, Record.extract(:mod, from_lib: "inets/include/httpd.hrl"))

  @reset 1_800_000_000

  def start(repos, opts \\ []) do
    dir = Keyword.fetch!(opts, :dir)
    File.mkdir_p!(dir)
    state = %{repos: repos, limited: Keyword.get(opts, :limited, false)}
    Application.put_env(:mx, __MODULE__, state)
    :inets.start()

    {:ok, server} =
      :inets.start(:httpd,
        port: 0,
        server_name: ~c"mx-fake-github",
        server_root: String.to_charlist(dir),
        document_root: String.to_charlist(dir),
        bind_address: {127, 0, 0, 1},
        modules: [__MODULE__]
      )

    port = :httpd.info(server)[:port]

    settings =
      for key <- [:github_raw_url, :github_api_url, :github_dir],
          do: {key, Application.get_env(:mx, key)}

    Application.put_env(:mx, :github_raw_url, "http://127.0.0.1:#{port}/raw")
    Application.put_env(:mx, :github_api_url, "http://127.0.0.1:#{port}/api")
    Application.put_env(:mx, :github_dir, Path.join(dir, "cache"))

    on_exit(fn ->
      :inets.stop(:httpd, server)
      Application.delete_env(:mx, __MODULE__)

      for {key, value} <- settings do
        if value, do: Application.put_env(:mx, key, value), else: Application.delete_env(:mx, key)
      end
    end)

    port
  end

  @doc "The time the fake rate limit resets, as GitHub gives it in seconds since 1970."
  def reset, do: @reset

  @doc false
  def unquote(:do)(data) do
    %{path: path} = URI.parse(to_string(mod(data, :request_uri)))
    segments = path |> String.split("/", trim: true) |> Enum.map(&URI.decode/1)
    {:proceed, [response: answer(segments, Application.fetch_env!(:mx, __MODULE__))]}
  end

  defp answer(["raw", owner, repo, ref | path], %{repos: repos}) do
    case get_in(repos, ["#{owner}/#{repo}", ref, Enum.join(path, "/")]) do
      nil -> respond(404, "404: Not Found")
      :fail -> respond(500, "500")
      content -> respond(200, content)
    end
  end

  defp answer(["api" | _], %{limited: true}) do
    respond(403, ~s({"message": "API rate limit exceeded"}), [
      {:"x-ratelimit-remaining", ~c"0"},
      {:"x-ratelimit-reset", Integer.to_charlist(@reset)}
    ])
  end

  defp answer(["api", "repos", owner, repo, "git", "trees" | ref], %{repos: repos}) do
    case get_in(repos, ["#{owner}/#{repo}", Enum.join(ref, "/")]) do
      nil ->
        respond(404, ~s({"message": "Not Found"}))

      files ->
        tree = for path <- Map.keys(files), do: %{path: path, type: "blob"}
        respond(200, JSON.encode!(%{tree: tree}))
    end
  end

  defp answer(["api", "repos", owner, repo], %{repos: repos}) do
    if Map.has_key?(repos, "#{owner}/#{repo}") do
      respond(200, "{}")
    else
      respond(404, ~s({"message": "Not Found"}))
    end
  end

  defp answer(_segments, _state), do: respond(404, "")

  defp respond(code, body, headers \\ []) do
    body = :binary.bin_to_list(body)
    {:response, [code: code, content_length: Integer.to_charlist(length(body))] ++ headers, body}
  end
end
