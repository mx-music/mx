defmodule Mx.MixProject do
  use Mix.Project

  def project do
    [
      app: :mx,
      source_url: "https://github.com/rodrigues/mx",
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [licenses: ["MIT"]],
      docs: docs(),
      test_ignore_filters: [~r"^test/support/"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :xmerl],
      mod: {Mx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:midiex, "~> 0.6.4"},
      {:vix, "~> 0.43"},
      {:pythonx, "~> 0.4.11"},
      {:rustler, "~> 0.38.0", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.4", only: [:dev, :test], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp docs do
    [
      name: "mx",
      output: "docs",
      formatters: ["html", "markdown"],
      main: "readme",
      extras: [
        "README.md",
        "documentation/notation.md",
        "documentation/instruments.md",
        "documentation/scores.md",
        "documentation/examples.md",
        "documentation/audiveris.md",
        "documentation/architecture.md"
      ],
      groups_for_extras: [
        Guides: ~w(notation instruments scores examples) |> Enum.map(&"documentation/#{&1}.md"),
        Setup: ["documentation/audiveris.md"],
        Internals: ["documentation/architecture.md"]
      ],
      assets: %{"documentation/assets" => "assets"},
      before_closing_body_tag: &docs_body_tag/1,
      groups_for_modules: [
        Music: [Mx, ~r/^Mx\.Music/, ~r/^Mx\.Song/, Mx.Notes, Mx.Tempo, ~r/^Mx\.Pass/],
        Samples: [Mx.Samples, Mx.Sampled, Mx.GitHub],
        Playing: [
          Mx.Session,
          Mx.Player,
          Mx.Band,
          Mx.Loop,
          Mx.Inputs,
          Mx.Out,
          Mx.Watcher,
          Mx.Clock,
          Mx.Application
        ],
        Engine: [~r/^Mx\.Engine/, Mx.Synths, Mx.OSC, Mx.Render],
        Instruments: [~r/^Mx\.Instrument($|\.)/],
        Measuring: [
          ~r/^Mx\.Measure/,
          Mx.Fit,
          Mx.Signal,
          Mx.FFT,
          Mx.Spectrogram,
          Mx.Audio,
          Mx.Recording
        ],
        Scores: [
          Mx.ABC,
          Mx.Score,
          Mx.Notation,
          Mx.Scan,
          Mx.Audiveris,
          Mx.Transcriber,
          ~r/^Mx\.Hum/
        ],
        "Test support": [
          Mx.FakeGitHub,
          Mx.Timeline,
          Mx.Voice,
          ~r/^Mx\.Instruments\./,
          ~r/^Mx\.Paired\./
        ]
      ],
      nest_modules_by_prefix: [
        Mx.Music,
        Mx.Song,
        Mx.Pass,
        Mx.Engine,
        Mx.Instrument,
        Mx.Measure,
        Mx.Hum,
        Mx.Instruments,
        Mx.Paired
      ]
    ]
  end

  defp docs_body_tag(:html) do
    """
    <link rel="stylesheet" href="assets/mermaid.css">
    <script src="assets/mermaid.js"></script>
    """
  end

  defp docs_body_tag(_formatter), do: ""
end
