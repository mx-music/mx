# Used by "mix format"
locals_without_parens = [
  attr: 2,
  attr: 3,
  envelope_attrs: 1,
  defsynth: 2,
  defeffect: 2,
  defsound: 2,
  defsoundp: 2,
  part: 2,
  bus: 2,
  kit: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,examples}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
