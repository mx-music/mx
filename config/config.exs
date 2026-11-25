import Config

# `MX_GPU=1 mix compile --force` builds the struck fit by gradient descent with MLX, on macOS.
config :mx, gpu: System.get_env("MX_GPU") in ["1", "true"]

if config_env() == :test do
  config :mx, samples_dir: Path.expand("../test/support/samples", __DIR__)
end
