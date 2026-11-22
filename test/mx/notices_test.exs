defmodule Mx.NoticesTest do
  use ExUnit.Case, async: true

  @notices "THIRD_PARTY_NOTICES.md"

  defp crates do
    for [_, name, version, licence] <-
          Regex.scan(~r/^- (\S+) (\S+), (.+), https:\/\/crates\.io\//m, File.read!(@notices)),
        do: {name, version, licence}
  end

  defp locked do
    "native/mxs_nif/Cargo.lock"
    |> File.read!()
    |> String.split("[[package]]")
    |> Enum.flat_map(fn package ->
      case Regex.run(~r/name = "(.+)"\nversion = "(.+)"/, package) do
        [_, name, version] -> [{name, version}]
        nil -> []
      end
    end)
    |> MapSet.new()
  end

  test "the Hex package holds the notices" do
    assert @notices in Mix.Project.config()[:package][:files]
  end

  test "symphonia-core is listed under MPL-2.0 with its version and where its source is" do
    {"symphonia-core", version, "MPL-2.0"} = List.keyfind(crates(), "symphonia-core", 0)
    assert {"symphonia-core", version} in locked()
    assert File.read!(@notices) =~ "https://crates.io/crates/symphonia-core/#{version}"
  end

  test "every crate listed is in the native lock file at its version, mxs among them" do
    listed = crates()
    assert length(listed) > 150
    for {name, version, _} <- listed, do: assert({name, version} in locked(), name)
    assert List.keymember?(listed, "mxs", 0)
    refute List.keymember?(listed, "mxs_nif", 0)
  end

  test "midiex and rustler_precompiled are listed with their licences and versions" do
    notices = File.read!(@notices)
    {:ok, lock} = File.read("mix.lock")

    for {dep, licence} <- [{"midiex", "MIT"}, {"rustler_precompiled", "Apache-2.0"}] do
      [_, version] = Regex.run(~r/"#{dep}": \{:hex, :#{dep}, "([^"]+)"/, lock)

      assert notices =~
               "- #{dep} #{version}, #{licence}, https://hex.pm/packages/#{dep}/#{version}"
    end
  end

  @tag :cargo_about
  @tag :tmp_dir
  test "the notices are what the script writes from the lock file now", %{tmp_dir: dir} do
    out = Path.join(dir, @notices)
    {_, 0} = System.cmd("elixir", ["scripts/notices.exs", out], stderr_to_stdout: true)
    assert File.read!(out) == File.read!(@notices)
  end
end
