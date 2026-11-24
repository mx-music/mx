defmodule Mx.MixProject do
  # A git checkout builds mxs itself, so it needs Rustler; a Hex install downloads mxs built.
  @checkout File.dir?(Path.join(__DIR__, ".git"))

  use Mix.Project

  def project do
    [
      app: :mx,
      source_url: "https://github.com/mx-music/mx",
      version: "0.2.2",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Write music in Elixir, played by mxs, its own sound engine in Rust",
      package: package(),
      docs: docs(),
      escript: [
        main_module: Mx.CLI,
        name: "mx",
        app: nil,
        include_priv_for: [:mx, :midiex],
        strip_beams: [keep: ["Docs"]]
      ],
      test_ignore_filters: [~r"^test/support/"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mx-music/mx"},
      files: ~w(
        lib
        priv/page.html
        priv/samples.txt
        native/mxs_nif/src
        native/mxs_nif/Cargo.toml
        native/mxs_nif/Cargo.lock
        checksum-*.exs
        mix.exs
        .formatter.exs
        README.md
        CHANGELOG.md
        LICENSE
        THIRD_PARTY_NOTICES.md
        LICENSE-designs.md
      )
    ]
  end

  def cli, do: [preferred_envs: ["mx.bench.paired": :test]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :xmerl],
      mod: {Mx.Application, []}
    ]
  end

  defp deps do
    [
      {:midiex, "~> 0.6.4"},
      {:rustler, "~> 0.38.0", optional: not @checkout, runtime: false},
      {:rustler_precompiled, "~> 0.10.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.4", only: [:dev, :test], runtime: false}
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
        "CHANGELOG.md",
        "documentation/first_song.md",
        "documentation/cheatsheet.cheatmd",
        "documentation/playing.md",
        "documentation/notation.md",
        "documentation/instruments.md",
        "documentation/scores.md",
        "documentation/examples.md",
        "documentation/architecture.md",
        "documentation/development.md"
      ],
      groups_for_extras: [
        Guides:
          ["documentation/first_song.md", "documentation/cheatsheet.cheatmd"] ++
            Enum.map(~w(playing notation instruments scores examples), &"documentation/#{&1}.md"),
        Internals: ["documentation/architecture.md", "documentation/development.md"]
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
          Mx.Waveform,
          Mx.Video,
          Mx.PNG,
          Mx.Audio,
          Mx.Recording
        ],
        Scores: [
          Mx.Score,
          Mx.Notation,
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
