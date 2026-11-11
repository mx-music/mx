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
      extras: ["README.md" | Path.wildcard("documentation/*.md")],
      groups_for_modules: [
        Music: [Mx, Mx.Music, Mx.Song, Mx.Notes, Mx.Tempo, Mx.Pass, Mx.Samples],
        Playing: [Mx.Session, Mx.Player, Mx.Band, Mx.Loop, Mx.Inputs, Mx.Out, Mx.Watcher],
        Engine: [~r/^Mx\.Engine/, Mx.Synth, Mx.Synths, Mx.OSC, Mx.Render],
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
        ]
      ],
      nest_modules_by_prefix: [Mx.Measure, Mx.Hum]
    ]
  end
end
