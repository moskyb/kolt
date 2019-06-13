defmodule Kolt.MonitorTest do
  use ExUnit.Case, async: true
  import Kolt.Monitor
  alias Mimic
  import Mimic

  @client :dummy_client
  @endpoints [{'localhost', 9095}]

  setup :verify_on_exit!

  setup do
    Mimic.stub(:brod)
    Mimic.stub(:telemetry)
    :ok
  end

  defp topic_offset_responses(topic) do
    {:ok, [%{partition_responses: [%{offset: 3, partition: 0}, %{offset: 2, partition: 1}], topic: topic}]}
  end

  describe ".handle_info(:process!)" do
    test "when brod returns the consumer offsets properly, it sends data about the offsets to :telemetry" do
      :brod
      # It fetches the committed offsets - the offset that each consumer is on
      |> Mimic.expect(:fetch_committed_offsets, fn @client, "group_one" -> topic_offset_responses("topic_one") end)
      # It then fetches the maximum offset for each partition that it got a commit offset for
      |> Mimic.expect(:resolve_offset, fn @endpoints, "topic_one", 0 -> {:ok, 3} end)
      |> Mimic.expect(:resolve_offset, fn @endpoints, "topic_one", 1 -> {:ok, 3} end)

      p_zero_measurements = %Kolt.Monitor.Measurements{partition_offset: 3, consumer_offset: 3, offset_lag: 0}
      p_zero_metadata = %Kolt.Monitor.Metadata{client: @client, endpoints: @endpoints, topic: "topic_one", partition: 0}

      p_one_measurements = %Kolt.Monitor.Measurements{partition_offset: 3, consumer_offset: 2, offset_lag: 1}
      p_one_metadata = %Kolt.Monitor.Metadata{p_zero_metadata | partition: 1}

      :telemetry
      |> Mimic.expect(:execute, fn [:kafka, :topic, :offset_lag], ^p_zero_measurements, ^p_zero_metadata -> :ok end)
      |> Mimic.expect(:execute, fn [:kafka, :topic, :offset_lag], ^p_one_measurements, ^p_one_metadata -> :ok end)

      state = %Kolt.Monitor{consumer_group_ids: ["group_one"], kafka_client: @client}

      handle_info(:process!, state)
    end

    test "when brod returns no consumer offset, it doesn't hit StatsD and logs the mismatch" do
      :brod
      |> Mimic.expect(:fetch_committed_offsets, fn @client, "group_one" -> {:ok, []} end)

      Mimic.reject(&:telemetry.execute/3)
      state = %Kolt.Monitor{consumer_group_ids: ["group_one"], kafka_client: @client}

      handle_info(:process!, state)
    end

    test "no matter what happens, it always reschedules itself to run in a little while" do
      state = %Kolt.Monitor{consumer_group_ids: [], kafka_client: @client, poll_delay: 0}
      handle_info(:process!, state)
      assert_receive :process!
    end
  end
end
