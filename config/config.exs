import Config

config :mx, audiveris: System.get_env("AUDIVERIS")
config :mx, transcriber_model: System.get_env("MX_TRANSCRIBER_MODEL")

if config_env() == :test do
  config :mx, samples_dir: Path.expand("../test/support/samples", __DIR__)
end
