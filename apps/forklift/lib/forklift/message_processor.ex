defmodule Forklift.MessageProcessor do
  @moduledoc false
  require Logger
  alias Forklift.{MessageAccumulator, DatasetRegistryServer, RedisClient}
  alias SCOS.{RegistryMessage, DataMessage}

  @data_topic Application.get_env(:forklift, :data_topic)
  @registry_topic Application.get_env(:forklift, :registry_topic)

  def handle_messages(messages) do
    Enum.each(messages, &process_message/1)
  end

  defp process_message(%{topic: topic, value: value}) do
    case topic do
      @data_topic -> process_data_message(value)
      @registry_topic -> process_registry_message(value)
      _ -> Logger.error("Unknown topic #{topic} with message #{value}")
    end
  end

  defp process_data_message(value) do
    RedisClient.write(value)

    with {:ok, data_message} <- DataMessage.new(value),
         {:ok, pid} <- start_server(data_message.dataset_id) do
      MessageAccumulator.send_message(pid, data_message.payload)
    else
      {:error, reason} -> Logger.error("Invalid data message: #{value} : #{inspect(reason)}")
    end
  end

  def process_registry_message(value) do
    with {:ok, registry_message} <- RegistryMessage.new(value) do
      DatasetRegistryServer.send_message(registry_message)
    else
      {:error, reason} -> Logger.error("Unable to process message: #{value} : #{inspect(reason)}")
    end
  end

  defp start_server(dataset_id) do
    case MessageAccumulator.start_link(dataset_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      _error -> {:error, "Error starting/locating DataSet GenServer"}
    end
  end
end
