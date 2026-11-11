# Prints each public function and macro of mx without a @doc, and exits with 1 if there is one.
# A callback marked @impl counts as documented, since Elixir hides it from the docs.
# Run with: mix run --no-start scripts/undocumented.exs

{:ok, modules} = :application.get_key(:mx, :modules)

missing =
  for module <- Enum.sort(modules),
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(module),
      {{kind, name, arity}, anno, _, :none, _} <- docs,
      kind in [:function, :macro] do
    source = module.module_info(:compile)[:source]
    file = Path.relative_to_cwd(to_string(source))
    line = :erl_anno.line(anno)
    "#{file}:#{line}: #{inspect(module)}.#{name}/#{arity}"
  end

Enum.each(missing, &IO.puts/1)

if missing != [] do
  count = length(missing)
  IO.puts("\n#{count} public functions or macros have no @doc; give each one, or @doc false to hide it.")
  System.halt(1)
end
