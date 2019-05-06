defmodule Forklift.DatasetWriter do
  @moduledoc false
  require Logger

  alias Forklift.{DataBuffer, PersistenceClient, RetryTracker, DeadLetterQueue}
  alias SmartCity.Data

  @jobs_registry Forklift.Application.dataset_jobs_registry()

  def perform(dataset_id) do
    if get_lock(dataset_id) do
      upload_data(dataset_id)
    end
  end

  defp upload_data(dataset_id) do
    pending = DataBuffer.get_pending_data(dataset_id)

    case upload_pending_data(dataset_id, pending) do
      :continue ->
        unread = DataBuffer.get_unread_data(dataset_id)
        upload_unread_data(dataset_id, unread)
        :ok

      :retry ->
        :ok
    end
  end

  defp upload_unread_data(dataset_id, []) do
    DataBuffer.cleanup_dataset(dataset_id)
  end

  defp upload_unread_data(dataset_id, data) do
    payloads = extract_payloads(data)

    with {:ok, timing} <- PersistenceClient.upload_data(dataset_id, payloads) do
      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      IO.inspect(payloads, label: "POST UPLOAD 2 (payloads) >>>>>")
      add_timing_and_send_to_kafka(timing, data)

      DataBuffer.mark_complete(dataset_id, data)
      DataBuffer.reset_empty_reads(dataset_id)
    end
  end

  defp add_timing_and_send_to_kafka(presto_timing, wrapped_messages) do
    Enum.map(wrapped_messages, fn data_message -> process_data_message(data_message, presto_timing) end)
  end

  defp process_data_message(data_message, presto_timing) do
    data_message =
      data_message
      |> Map.get(:data)
      |> Data.add_timing(presto_timing)
      |> add_total_timing()
      |> Map.from_struct()
      |> unwrap_key()

    PersistenceClient.send_to_kafka("streaming-persisted", data_message.kafka_key, data_message.message)
  end

  defp unwrap_key(data_message) do
    %{
      kafka_key: data_message.operational.kafka_key,
      message:
        data_message
        |> remove_from_operational(:kafka_key)
        |> remove_from_operational(:forklift_start_time)
    }
  end

  defp remove_from_operational(data_message, key) do
    data_message[:operational][key]
    |> pop_in()
    |> elem(1)
  end

  defp add_total_timing(message) do
    Data.add_timing(
      message,
      Data.Timing.new(
        "forklift",
        "total_time",
        message.operational.forklift_start_time,
        Data.Timing.current_time()
      )
    )
  end

  def make_kafka_message(value) do
    %{
      topic: "streaming-persisted",
      value: value |> Jason.encode!(),
      offset: :rand.uniform(999)
    }
  end

  defp upload_pending_data(_dataset_id, []), do: :continue

  defp upload_pending_data(dataset_id, data) do
    payloads = extract_payloads(data)

    case PersistenceClient.upload_data(dataset_id, payloads) do
      {:ok, timing} ->
        # credo:disable-for-next-line Credo.Check.Warning.IoInspect
        IO.inspect(payloads, label: "POST UPLOAD (payloads) >>>>>")
        cleanup_pending(dataset_id, data)
        add_timing_and_send_to_kafka(timing, data)

        :continue

      {:error, reason} ->
        if RetryTracker.get_and_increment_retries(dataset_id) > 3 do
          Enum.each(data, fn message -> DeadLetterQueue.enqueue(message, reason: reason) end)
          cleanup_pending(dataset_id, data)

          :continue
        else
          :retry
        end
    end
  end

  defp extract_payloads(data) do
    Enum.map(data, fn %{data: d} -> d.payload end)
  end

  defp cleanup_pending(dataset_id, data) do
    DataBuffer.mark_complete(dataset_id, data)
    DataBuffer.cleanup_dataset(dataset_id)
    RetryTracker.reset_retries(dataset_id)
  end

  defp get_lock(dataset_id) do
    case Registry.register(@jobs_registry, dataset_id, :running) do
      {:ok, _pid} ->
        true

      {:error, {:already_registered, pid}} ->
        Logger.info("Dataset: #{dataset_id} is already being processed by #{inspect(pid)}")
        false
    end
  end
end
