# Kolt: The <b>K</b>afka <b>O</b>ffset <b>L</b>ag <b>T</b>racker

Kolt is a library that gets the maximum offset for the given Kafka topics, and compares them with the offsets of any consumers on that Topic. This allows you to see how far 'behind' the producers your kafka consumers are.

Kolt uses the wonderful [beam-telemetry](https://github.com/beam-telemetry/telemetry) project to output its metrics, allowing you to track or store them in whatever manner your please.

## Installation

To install, simply add kolt to your `mix.exs` file:

```elixir
def deps do
  [
    # ...
    {:kolt, "~> 0.1.0"},
    # ...
  ]
end
```

## Usage

Kolt uses [Brod](https://github.com/klarna/brod/) to communicate with kafka, and gets Kafka client information from Brod's config in your `mix.exs` file. It should look something like this:
```elixir
config :brod,
  clients: [
    cool_client: [
      endpoints: {'localhost', 9092},
      reconnect_cool_down_seconds: 10,
      auto_start_producers: true,
      default_producer_config: []
    ]
  ]
```

Note that Kolt won't be able to track offsets on Topics outside of the clients given.

To start Kolt, simply add the `Kolt.Monitor` GenServer to your application's supervision tree, passing it the consumer groups whose offset lags you want to track, as well as the kafka client that those consumer groups are registered on:

```elixir
defmodule MyApplication do
  @moduledoc false

  use Application

  def start(_, _) do
    import Supervisor.Spec

    tree =
      [
        # ...
        {OffsetLagMonitor, [["consumer_group_one", "consumer_group_two"], :cool_client]},
        # ...
      ]

    opts = [name: MyApplication.Supervisor, strategy: :one_for_one]
    Supervisor.start_link(tree, opts)
  end
end
```

Once this GenServer is in place, Kolt will check offset lags every 10 seconds, and output them using [BEAM Telemetry](https://github.com/beam-telemetry/telemetry). This means that to consume the metrics Kolt produces, you'll need to attach a function to Kolt's telemetry stream.

Kolt outputs telemetry in the namespace `[:kafka, :topic, :offset_lag]`, so you'll to call `:telemetry.attach/4` on this namespace. I recommend doing this in your application's start method:
```elixir
def start(_, _) do
  import Supervisor.Spec

  tree =
    [
      # ...
      {OffsetLagMonitor, [["consumer_group_one", "consumer_group_two"], :cool_client]},
      # ...
    ]

  opts = [name: MyApplication.Supervisor, strategy: :one_for_one]
  :telemetry.attach("offset-lag-metrics", [:kafka, :topic, :offset_lag], &TelemetryHandler.handle_event/4, nil)
  Supervisor.start_link(tree, opts)
end
```

## Thanks

