defmodule Kolt.Monitor do
  @moduledoc """
  Process that monitors the offset lag for running consumer groups. It outputs these
  """
  use GenServer

  @type t :: %__MODULE__{
          consumer_group_ids: [String.t()],
          kafka_client: atom,
          poll_delay: 10_000 | integer()
        }
  defstruct [:consumer_group_ids, :kafka_client, poll_delay: 10_000]

  defmodule Measurements do
    @type t :: %__MODULE__{offset_lag: integer(), partition_offset: integer(), consumer_offset: integer()}
    defstruct [:offset_lag, :partition_offset, :consumer_offset]
  end

  defmodule Metadata do
    @type endpoint() :: {charlist(), integer()}

    @type t :: %__MODULE__{
      client: atom(),
      endpoints: [endpoint()],
      topic: String.t(),
      partition: integer()
    }
    defstruct [:client, :endpoints, :topic, :partition]
  end

  def start_link([state = %Kolt.Monitor{}]) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    send(self(), :process!)

    {:ok, state}
  end

  def handle_info(:process!, state) do
    track_consumer_group_lag(state)

    Process.send_after(self(), :process!, state.poll_delay)

    {:noreply, state}
  end

  defp track_consumer_group_lag(%Kolt.Monitor{consumer_group_ids: consumer_group_ids, kafka_client: kafka_client}) do
    Enum.each(consumer_group_ids, fn group ->
      endpoints = kafka_endpoints(kafka_client)
      offset_lag_per_group(group, kafka_client, endpoints)
    end)
  end

  defp offset_lag_per_group(group_name, client, endpoints) do
    with {:ok, [resp]} <- :brod.fetch_committed_offsets(client, group_name) do
      gauge_offset_lag(client, endpoints, resp.topic, resp.partition_responses)
    end
  end

  defp gauge_offset_lag(client, endpoints, topic, partition_metrics) do
    Enum.each(partition_metrics, fn metric ->
      [consumer_offset, partition_number] = metric |> Map.take(~w(offset partition)a) |> Map.values()

      {:ok, partition_offset} = :brod.resolve_offset(endpoints, topic, partition_number)

      offset_lag = partition_offset - consumer_offset

      measurements = %Measurements{offset_lag: offset_lag, partition_offset: partition_offset, consumer_offset: consumer_offset}
      metadata = %Metadata{client: client, endpoints: endpoints, topic: topic, partition: partition_number}


      :telemetry.execute([:kafka, :topic, :offset_lag], measurements, metadata)
    end)
  end

  defp kafka_endpoints(client) do
    get_in(Application.fetch_env!(:brod, :clients), [client, :endpoints])
  end
end
