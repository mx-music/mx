ExUnit.start(
  assert_receive_timeout: 2000,
  refute_receive_timeout: 1000,
  exclude: [
    :engine,
    :timing,
    :iowa,
    :vsco,
    :vcsl,
    :ffmpeg,
    :philharmonia,
    :nasa,
    :nsynth,
    :anderson,
    :cargo_about
  ]
)
