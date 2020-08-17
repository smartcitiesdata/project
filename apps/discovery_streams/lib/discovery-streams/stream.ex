defmodule DiscoveryStreams.Stream do
  @moduledoc """
  Process to wrap the processes that push messages through `discovery_streams`.
  This `GenServer` links processes for reading messages from a `Source.t()` impl
  """

  use GenServer, shutdown: 30_000
  use Annotated.Retry
  use Properties, otp_app: :discovery_streams
  require Logger
  # import Definition, only: [identifier: 1]
  getter(:endpoints)

  @max_retries get_config_value(:max_retries, default: 50)

  # @type init_opts :: [
  #         load: Load.t()
  #       ]

  def start_link(init_opts) do
    server_opts = Keyword.take(init_opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl GenServer
  def init(init_opts) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "#{__MODULE__}: init with #{inspect(init_opts)}" end)

    state = %{
      dataset: Keyword.fetch!(init_opts, :dataset)
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    with {:ok, source_pid} <- start_source(state.dataset) do
      new_state =
        state
        |> Map.put(:source_pid, source_pid)

      {:noreply, new_state}
    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_source(dataset) do
    context =
      Source.Context.new!(
        handler: DiscoveryStreams.Stream.SourceHandler,
        app_name: :discovery_streams,
        dataset_id: dataset.id,
        assigns: %{
          dataset: dataset,
          kafka: %{
            offset_reset_policy: :reset_to_latest
          }
        }
      )

    # TODO: stop hardcoding the endpoints
    Source.start_link(Kafka.Topic.new!(endpoints: [localhost: 9092], name: "transformed-#{dataset.id}"), context)
  end

  @impl GenServer
  def terminate(reason, state) do
    IO.inspect(state, label: "State i")

    if Map.has_key?(state, :source) do
      pid = Map.get(state, :source_pid)
      Source.stop(state.load.source, pid)
    end

    reason
  end

  defp kill(pid, reason) do
    Process.exit(pid, reason)

    receive do
      {:EXIT, ^pid, _} ->
        :ok
    after
      20_000 -> :ok
    end
  end
end
