defmodule Reaper.DataExtract.Processor do
  @moduledoc """
  This module processes a data source and sends its data to the output topic
  """
  use Properties, otp_app: :reaper

  import SmartCity.Event,
    only: [
      event_log_published: 0
    ]

  require Logger

  alias Reaper.{
    Decoder,
    DataSlurper,
    UrlBuilder,
    Persistence
  }

  alias Reaper.DataExtract.{ValidationStage, SchemaStage, LoadStage, ExtractStep}
  alias Reaper.Cache.MsgCountCache

  use Retry

  @min_demand 500
  @max_demand 1_000

  @instance_name Reaper.instance_name()

  @doc """
  Downloads, decodes, and sends data to a topic
  """
  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  @spec process(SmartCity.Ingestion.t(), DateTime.t()) :: Redix.Protocol.redis_value() | no_return()
  def process(%SmartCity.Ingestion{} = unprovisioned_ingestion, extract_time) do
    Process.flag(:trap_exit, true)

    ingestion =
      unprovisioned_ingestion
      |> Providers.Helpers.Provisioner.provision()

    validate_destination(ingestion)
    validate_cache(ingestion)

    Enum.each(unprovisioned_ingestion.targetDatasets, fn dataset_id ->
      event_data = %SmartCity.EventLog{
        title: "Ingestion Started",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Ingestion has started",
        ingestion_id: unprovisioned_ingestion.id,
        dataset_id: dataset_id
      }

      Brook.Event.send(@instance_name, event_log_published(), :reaper, event_data)
    end)

    {:ok, producer_stage} = create_producer_stage(ingestion)
    {:ok, validation_stage} = ValidationStage.start_link(cache: ingestion.id, ingestion: ingestion)
    {:ok, schema_stage} = SchemaStage.start_link(cache: ingestion.id, ingestion: ingestion)
    {:ok, load_stage} = LoadStage.start_link(cache: ingestion.id, ingestion: ingestion, start_time: extract_time)

    GenStage.sync_subscribe(load_stage, to: schema_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(schema_stage, to: validation_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(validation_stage, to: producer_stage, min_demand: @min_demand, max_demand: @max_demand)

    wait_for_completion([producer_stage, validation_stage, schema_stage, load_stage])

    Enum.each(unprovisioned_ingestion.targetDatasets, fn dataset_id ->
      event_data = %SmartCity.EventLog{
        title: "Data Retrieved",
        timestamp: DateTime.utc_now() |> DateTime.to_string(),
        source: "Reaper",
        description: "Successfully downloaded data and placed on data pipeline to begin processing.",
        ingestion_id: unprovisioned_ingestion.id,
        dataset_id: dataset_id
      }

      Brook.Event.send(@instance_name, event_log_published(), :reaper, event_data)
    end)

    Persistence.remove_last_processed_index(ingestion.id)

    messages_processed_count(ingestion.id)
  rescue
    error ->
      Logger.error(Exception.format_stacktrace(__STACKTRACE__))

      Logger.error(
        "Unable to continue processing ingestion #{inspect(unprovisioned_ingestion)} - Error #{inspect(error)}"
      )

      reraise error, __STACKTRACE__
  after
    unprovisioned_ingestion.id
    |> DataSlurper.determine_filename()
    |> File.rm()
  end

  defp create_producer_stage(%SmartCity.Ingestion{extractSteps: extract_steps} = ingestion) do
    %{output_file: output_file} = ExtractStep.execute_extract_steps(ingestion, extract_steps)

    output_file
    |> Decoder.decode(ingestion)
    |> Stream.with_index()
    |> GenStage.from_enumerable()
  end

  defp validate_destination(ingestion) do
    topic = "#{output_topic_prefix()}-#{ingestion.id}"
    create_topic(topic)
    start_topic_producer(topic)
  end

  defp validate_cache(%SmartCity.Ingestion{allow_duplicates: false, id: id}) do
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: id})
  end

  defp validate_cache(_ingestion), do: nil

  defp wait_for_completion([]), do: true

  defp wait_for_completion(pids) do
    receive do
      {:EXIT, from, :normal} ->
        wait_for_completion(pids -- [from])

      {:EXIT, _from, reason} ->
        raise "Stage failed reason: #{inspect(reason)}"

      unknown ->
        Logger.warn("Unknown message received: #{inspect(unknown)}")
        wait_for_completion(pids)
    end
  end

  defp create_topic(topic) do
    retry with: exponential_backoff() |> randomize() |> cap(2_000) |> expiry(30_000), atoms: [false] do
      Elsa.create_topic(elsa_brokers(), topic)
      Process.sleep(100)
      Elsa.topic?(elsa_brokers(), topic)
    after
      true -> true
    else
      _ -> raise "Topic does not exist, everything is terrible!"
    end
  end

  defp start_topic_producer(topic) do
    connection_name = :"#{topic}_producer"

    {:ok, _pid} =
      Elsa.Supervisor.start_link(connection: connection_name, endpoints: elsa_brokers(), producer: [topic: topic])

    Elsa.Producer.ready?(connection_name)
  end

  defp messages_processed_count(ingestion_id) do
    case MsgCountCache.get(ingestion_id) do
      {:ok, count} ->
        count

      {:error, error} ->
        raise "Unable to retrieve messages processed count ingestion #{ingestion_id} with error #{inspect(error)}"
    end
  end
end
