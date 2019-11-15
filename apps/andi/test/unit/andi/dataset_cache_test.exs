defmodule Andi.DatasetCacheTest do
  use ExUnit.Case

  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0]

  alias Andi.DatasetCache

  alias Brook.ViewState
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    datasets = Brook.get_all_values!(instance_name(), :dataset)

    Brook.Test.with_event(instance_name(), fn ->
      Enum.each(datasets, fn dataset ->
        ViewState.delete(:dataset, dataset.id)
      end)
    end)
  end

  describe "with cache started" do
    setup do
      GenServer.call(DatasetCache, :reset)

      :ok
    end

    test "datasets passed to put/1 are returned by get_all/0" do
      datasets = Enum.map(1..3, fn _ -> TDG.create_dataset([]) end)

      DatasetCache.put(datasets)
      results = DatasetCache.get_all()

      Enum.each(datasets, fn dataset ->
        assert Enum.member?(results, %{id: dataset.id, dataset: dataset})
      end)
    end

    test "ingested times passed to put/2 are returned by get_all/0" do
      time_stamps = [
        %{id: "abc", ingested_time: "122323"},
        %{id: "def", ingested_time: "332343"},
        %{id: "ghi", ingested_time: "4544564"}
      ]

      DatasetCache.put(time_stamps)
      results = DatasetCache.get_all()

      Enum.each(time_stamps, fn time_stamp ->
        assert Enum.member?(results, time_stamp)
      end)
    end

    test "dataset passed to put/1 is returned by get_all/0" do
      dataset = TDG.create_dataset([])

      DatasetCache.put(dataset)

      assert DatasetCache.get_all() |> Enum.member?(%{id: dataset.id, dataset: dataset})
    end

    test "ingested time passed to put/2 is returned by get_all/0" do
      id = "123"
      time_stamp = "11322232"
      DatasetCache.put(%{id: id, ingested_time: time_stamp})

      assert DatasetCache.get_all() |> Enum.member?(%{id: id, ingested_time: time_stamp})
    end

    test "a dataset and ingested time for the same id are returned by get_all/0 as a single, merged object" do
      dataset = TDG.create_dataset([])
      time_stamp = "11322232"

      DatasetCache.put(%{id: dataset.id, ingested_time: time_stamp})
      DatasetCache.put(dataset)

      expected = %{id: dataset.id, dataset: dataset, ingested_time: time_stamp}

      assert 1 == length(DatasetCache.get_all())
      assert expected == DatasetCache.get_all() |> List.first()
    end

    test "a dataset and ingested time for the same id are returned by get_all/0 as a single, merged object, regardless of order" do
      dataset = TDG.create_dataset([])
      time_stamp = "113222332"

      DatasetCache.put(dataset)
      DatasetCache.put(%{id: dataset.id, ingested_time: time_stamp})

      expected = %{id: dataset.id, dataset: dataset, ingested_time: time_stamp}

      assert 1 == length(DatasetCache.get_all())
      assert expected == DatasetCache.get_all() |> List.first()
    end
  end

  describe "init/0 callback" do
    test "inserts datasets from the view state" do
      datasets = Enum.map(1..3, fn _ -> TDG.create_dataset([]) end)

      Brook.Test.with_event(instance_name(), fn ->
        Enum.each(datasets, fn dataset ->
          ViewState.merge(:dataset, dataset.id, dataset)
        end)
      end)

      GenServer.call(DatasetCache, :reset)

      results = DatasetCache.get_all()

      Enum.each(datasets, fn dataset ->
        assert Enum.member?(results, %{id: dataset.id, dataset: dataset})
      end)
    end

    test "Event handler adds datasets to cache on dataset_update event" do
      GenServer.call(DatasetCache, :reset)

      datasets =
        Enum.map(1..3, fn _ ->
          dataset = TDG.create_dataset([])
          Brook.Event.send(instance_name(), dataset_update(), :andi_test, dataset)

          dataset
        end)

      results = DatasetCache.get_all()

      Enum.each(datasets, fn dataset ->
        assert Enum.member?(results, %{id: dataset.id, dataset: dataset})
      end)
    end
  end
end
