defmodule Mx.Sampled do
  @moduledoc """
  A sampled instrument: recordings of an instrument one key at a time, often at several strengths and in several takes, played as a part plays a synth.

  A folder's files give their note, strength and take in their names, as VCSL names them: "MBira4_pluck_Main_C#3_2_50_100_rr5.wav" is C#3, "BDrumNew_hit_v5_rr1_Sum.wav" strength 5, take 1.
  The name is split at underscores, spaces and hyphens, and a word such as C#3 or Bb2 is the note, v or vl and a number the strength, and rr and a number the take.
  Files of one note and strength are the takes of one key, in the order of their take and then their name.

  A note plays the key nearest to it, the lower one on a tie, at the rate that brings it to the note's pitch; vel picks a strength, the softest at 0 and the hardest at 1, spread evenly over the key's strengths.
  """

  alias Mx.Notes

  defstruct [:source, keys: %{}]

  # The sample players' options, but for the rate, start and finish a sampled instrument works out itself, and with vel.
  @not_options [:rate, :rate_slide, :start, :finish]

  @doc """
  The instrument whose recordings are in the files of `folder`, a folder of a GitHub repository as `{:github, repo, ref, folder}`, or listed as `{file, note: note, strength: strength, take: take}`; its files are read by `load/1`.
  A listed file is a path or `{:github, repo, ref, path}`, and what it does not give is read from its name.
  """
  def new(folder) when is_binary(folder), do: %__MODULE__{source: folder}

  def new({:github, _repo, _ref, _folder} = folder) do
    case Mx.Samples.check_github(folder) do
      :ok -> %__MODULE__{source: folder}
      {:error, message} -> raise ArgumentError, message
    end
  end

  def new(files) when is_list(files) and files != [] do
    files = Enum.map(files, &if(match?({_, opts} when is_list(opts), &1), do: &1, else: {&1, []}))

    for file <- files do
      case file do
        {path, opts} when is_binary(path) or (is_tuple(path) and elem(path, 0) == :github) ->
          case Enum.find(Keyword.keys(opts), &(&1 not in [:note, :strength, :take])) do
            nil -> :ok
            option -> raise ArgumentError, "sampled lists a file with no option #{option}"
          end

        other ->
          other = inspect(other)

          raise ArgumentError,
                "sampled lists files as {path, note: note, strength: s, take: t}, not #{other}"
      end
    end

    %__MODULE__{source: files}
  end

  def new(other) do
    other = inspect(other)
    raise ArgumentError, "sampled takes a folder or a list of files, not #{other}"
  end

  @doc "Reads the instrument's files into its keys, or returns `{:error, message}` naming the folder or the file."
  def load(%__MODULE__{source: {:github, repo, ref, folder}} = sampled) do
    dir = Mx.GitHub.local(repo, ref, folder)

    downloaded =
      if File.ls(dir) in [{:ok, []}, {:error, :enoent}] do
        Mx.Samples.download_source("#{repo}@#{ref}:#{folder}")
      else
        {:ok, nil}
      end

    case downloaded do
      {:ok, message} ->
        if message, do: IO.puts(message)
        load_folder(sampled, dir, "#{folder} of #{repo}")

      {:error, message} ->
        {:error, "cannot download folder #{folder} of #{repo}: #{message}"}
    end
  end

  def load(%__MODULE__{source: folder} = sampled) when is_binary(folder) do
    load_folder(sampled, Path.expand(folder), folder)
  end

  def load(%__MODULE__{source: files} = sampled) when is_list(files) do
    found =
      Enum.reduce_while(files, [], fn {file, opts}, found ->
        case local(file) do
          {:ok, path} ->
            {:cont, [{path, Map.merge(describe(Path.basename(path)), listed(opts))} | found]}

          {:error, message} ->
            {:halt, {:error, message}}
        end
      end)

    case found do
      {:error, message} -> {:error, message}
      found -> {:ok, %{sampled | keys: keys(Enum.reverse(found))}}
    end
  end

  defp local({:github, _, _, _} = file) do
    with {:error, message} <- Mx.Samples.path(file), do: {:error, message}
  end

  defp local(path) do
    if File.regular?(Path.expand(path)) do
      {:ok, Path.expand(path)}
    else
      {:error, "sampled file #{path} does not exist"}
    end
  end

  defp load_folder(sampled, dir, folder) do
    files =
      for path <- dir |> Path.join("*") |> Path.wildcard() |> Enum.sort(),
          File.regular?(path),
          described = describe(Path.basename(path)),
          described != %{},
          do: {path, described}

    case files do
      [] ->
        {:error, "folder #{folder} has no files whose names carry a note, a strength or a take"}

      files ->
        {:ok, %{sampled | keys: keys(files)}}
    end
  end

  defp listed(opts) do
    opts
    |> Keyword.take([:note, :strength, :take])
    |> Map.new(fn
      {:note, note} -> {:note, Notes.note(note)}
      other -> other
    end)
  end

  @doc "The note, strength and take a file's name carries, each only when it carries one."
  def describe(name) when is_binary(name) do
    name
    |> Path.rootname()
    |> String.split(["_", " ", "-"], trim: true)
    |> Enum.reduce(%{}, fn word, found ->
      cond do
        word =~ ~r/^[A-G][#b]?-?\d$/ ->
          Map.put(found, :note, Notes.parse(String.replace(word, "#", "s")))

        word =~ ~r/^vl?\d+$/ ->
          Map.put(found, :strength, digits(word))

        word =~ ~r/^rr\d+$/ ->
          Map.put(found, :take, digits(word))

        true ->
          found
      end
    end)
  end

  defp digits(word), do: word |> String.replace(~r/\D/, "") |> String.to_integer()

  # Each note's strengths, softest first, each with its takes in order.
  defp keys(files) do
    files
    |> Enum.group_by(fn {_, file} -> file[:note] end)
    |> Map.new(fn {note, files} ->
      strengths =
        files
        |> Enum.group_by(fn {_, file} -> file[:strength] end)
        |> Enum.sort_by(fn {strength, _} -> strength || 0 end)
        |> Enum.map(fn {_, files} ->
          files
          |> Enum.sort_by(fn {path, file} -> {file[:take] || 0, path} end)
          |> Enum.map(&elem(&1, 0))
        end)

      {note, List.to_tuple(strengths)}
    end)
  end

  @doc "Whether a sampled instrument takes an option."
  def option?(option) do
    option == :vel or (option not in @not_options and Mx.Synths.option?(:stereo_player, option))
  end

  @doc "The takes of the key and strength a note or `:own_note` at `vel` plays, with the rate it plays them at, or `{:error, message}`."
  def pick(%__MODULE__{keys: keys} = sampled, note, vel) do
    case nearest(keys, note) do
      nil when note == :own_note ->
        {:error, "#{sampled} has a note in every file's name, so each note needs a pitch"}

      nil ->
        {:error, "#{sampled} has no notes in its files' names, so it plays with hit"}

      {key, rate} ->
        strengths = Map.fetch!(keys, key)
        count = tuple_size(strengths)
        {:ok, {key, elem(strengths, min(trunc(vel * count), count - 1)), rate}}
    end
  end

  defp nearest(keys, :own_note), do: if(Map.has_key?(keys, nil), do: {nil, 1.0})

  defp nearest(keys, note) do
    case for key <- Map.keys(keys), key != nil, do: key do
      [] ->
        nil

      notes ->
        key = Enum.min_by(notes, &{abs(&1 - note), &1})
        {key, :math.pow(2, (note - key) / 12)}
    end
  end

  defimpl String.Chars do
    @doc false
    def to_string(%{source: folder}) when is_binary(folder), do: "sampled instrument #{folder}"

    def to_string(%{source: {:github, repo, _ref, folder}}) do
      "sampled instrument #{folder} of #{repo}"
    end

    def to_string(_sampled), do: "sampled instrument"
  end
end
