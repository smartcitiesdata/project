defmodule Forklift.IngestionProgressTest do
  alias Forklift.IngestionProgress
  use ExUnit.Case

  setup_all do
    on_exit(fn ->
      {:ok, _} = Redix.command(:redix, ["flushall"])
    end)
  end

  setup do
    on_exit(fn ->
      {:ok, _} = Redix.command(:redix, ["flushall"])
    end)

    [ingestion_id: Faker.UUID.v4(), extract_time: Timex.now() |> Timex.to_unix(), dataset: %{}]
  end

  describe "IngestionTest" do
    test "new_messages updates the message count when called", %{ingestion_id: ingestion_id, extract_time: extract_time} do
      IO.inspect("new_messages updates the message count when called", label: "Ryan")
      IngestionProgress.new_messages(1, ingestion_id, extract_time)
      resulting_count = Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_count"])
      assert resulting_count == "1"
    end

    test "new_messages returns :in_progress if message count *has not* met existing ingestion target", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time
    } do
      IO.inspect("new_messages returns :in_progress if message count *has not* met existing ingestion target",
        label: "Ryan"
      )

      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_target", 2])
      result = IngestionProgress.new_messages(1, ingestion_id, extract_time)
      assert result == :in_progress
    end

    test "new_messages returns :in_progress if message count ingestion target does not exist", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time
    } do
      IO.inspect("new_messages returns :in_progress if message count ingestion target does not exist", label: "Ryan")
      result = IngestionProgress.new_messages(1, ingestion_id, extract_time)
      assert result == :in_progress
    end

    test "new_messages returns :ingestion_complete if message count *has* met ingestion target", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time
    } do
      IO.inspect("new_messages returns :ingestion_complete if message count *has* met ingestion target", label: "Ryan")
      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_target", 1])
      result = IngestionProgress.new_messages(1, ingestion_id, extract_time)
      assert result == :ingestion_complete
    end

    test "new_messages resets _count and _target if message count *has* met ingestion target", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time
    } do
      IO.inspect("new_messages resets _count and _target if message count *has* met ingestion target", label: "Ryan")
      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_target", 1])
      IngestionProgress.new_messages(1, ingestion_id, extract_time)
      assert Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_target"]) == nil
      assert Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_count"]) == nil
    end

    test "store_target stores target value in redis", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time,
      dataset: dataset
    } do
      IO.inspect("store_target stores target value in redis", label: "Ryan")
      IngestionProgress.store_target(dataset, 7, ingestion_id, extract_time, 1000)
      assert Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_target"]) == "7"
    end

    test "store_target returns :in_progress if count doesn't exist", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time,
      dataset: dataset
    } do
      IO.inspect("store_target returns :in_progress if count doesn't exist", label: "Ryan")
      assert IngestionProgress.store_target(dataset, 7, ingestion_id, extract_time, 1000) == :in_progress
    end

    test "store_target returns :in_progress if count is *less than* new target", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time,
      dataset: dataset
    } do
      IO.inspect("store_target returns :in_progress if count is *less than* new target", label: "Ryan")
      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_count", 6])
      assert IngestionProgress.store_target(dataset, 7, ingestion_id, extract_time, 1000) == :in_progress
    end

    test "store_target returns :ingestion_complete if count meets new target", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time,
      dataset: dataset
    } do
      IO.inspect("store_target returns :ingestion_complete if count meets new target", label: "Ryan")
      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_count", 3])
      assert IngestionProgress.store_target(dataset, 3, ingestion_id, extract_time, 1000) == :ingestion_complete
    end

    test "ingestion count and target are cleared when target is achieved", %{
      ingestion_id: ingestion_id,
      extract_time: extract_time,
      dataset: dataset
    } do
      IO.inspect("ingestion count and target are cleared when target is achieved", label: "Ryan")
      Redix.command!(:redix, ["SET", get_extract_id(ingestion_id, extract_time) <> "_count", 3])
      IngestionProgress.store_target(dataset, 3, ingestion_id, extract_time, 1000)
      assert Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_target"]) == nil
      assert Redix.command!(:redix, ["GET", get_extract_id(ingestion_id, extract_time) <> "_count"]) == nil
    end

    defp get_extract_id(ingestion_id, extract_time) do
      ingestion_id <> "_" <> (extract_time |> Integer.to_string())
    end
  end
end
