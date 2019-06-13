# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :brod,
  clients: [
    dummy_client: [
      endpoints: [{'localhost', 9095}],
      reconnect_cool_down_seconds: 10,
      auto_start_producers: true,
      default_producer_config: []
    ],
  ]
