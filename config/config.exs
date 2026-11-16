import Config

if config_env() == :test do
  config :mx, samples_dir: Path.expand("../test/support/samples", __DIR__)
end
