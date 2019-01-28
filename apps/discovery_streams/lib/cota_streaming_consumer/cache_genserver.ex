defmodule CotaStreamingConsumer.CacheGenserver do
  @moduledoc "false"
  use GenServer

  def init(_) do
    {:ok, nil}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_cast({:put, cache, key, value}, state) do
    Cachex.put(cache, key, value)
    {:noreply, state}
  end
end
