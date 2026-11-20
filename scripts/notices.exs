# Writes THIRD_PARTY_NOTICES.md, or the path given, from the native crate's lock file and mix.lock.
# Run it before a release, with cargo-about installed: elixir scripts/notices.exs

out = List.first(System.argv(), "THIRD_PARTY_NOTICES.md")
native = "native/mxs_nif"
crates = Path.join(System.tmp_dir!(), "mx-crates-#{System.unique_integer([:positive])}.md")

{output, status} =
  System.cmd("cargo", ["about", "generate", "--fail", "-c", "about.toml", "about.hbs", "-o", crates],
    cd: native,
    stderr_to_stdout: true
  )

if status != 0, do: raise("cargo about failed:\n#{output}")

lock = File.read!("mix.lock")

packages =
  for {dep, licence} <- [{"midiex", "MIT"}, {"rustler_precompiled", "Apache-2.0"}] do
    [_, version] = Regex.run(~r/"#{dep}": \{:hex, :#{dep}, "([^"]+)"/, lock)
    "- #{dep} #{version}, #{licence}, https://hex.pm/packages/#{dep}/#{version}\n"
  end

text = crates |> File.read!() |> String.replace("ELIXIR_PACKAGES\n", Enum.join(packages))
File.rm!(crates)
File.write!(out, text)
