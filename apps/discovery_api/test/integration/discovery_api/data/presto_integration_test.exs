defmodule DiscoveryApi.Data.PrestoIngrationTest do
  use ExUnit.Case
  use Divo, services: [:redis, :presto, :metastore, :postgres, :minio, :zookeeper, :kafka, :"ecto-postgres", :elasticsearch]
  use DiscoveryApi.DataCase
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 3]

  setup do
    Helper.wait_for_brook_to_be_ready()
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  @moduletag capture_log: true
  test "returns empty list when dataset has no data saved" do
    organization = Helper.create_persisted_organization()

    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    system_name = dataset.technical.systemName

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!("create table if not exists #{system_name} (id integer, name varchar)")

    Brook.Event.send(DiscoveryApi.instance(), dataset_update(), "integration", dataset)

    eventually(
      fn ->
        assert get_dataset_preview(dataset.id) == []
      end,
      2000,
      20
    )
  end

  @moduletag capture_log: true
  test "returns results for datasets stored in presto" do
    organization = Helper.create_persisted_organization()

    dataset = TDG.create_dataset(%{technical: %{orgId: organization.id}})
    system_name = dataset.technical.systemName

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!("create table if not exists #{system_name} (id integer, name varchar)")

    DiscoveryApi.prestige_opts()
    |> Keyword.merge(receive_timeout: 10_000)
    |> Prestige.new_session()
    |> Prestige.query!(~s|insert into "#{system_name}" values (1, 'bob'), (2, 'mike')|)

    Brook.Event.send(DiscoveryApi.instance(), dataset_update(), "integration", dataset)

    expected = [%{"id" => 1, "name" => "bob"}, %{"id" => 2, "name" => "mike"}]

    eventually(
      fn ->
        assert get_dataset_preview(dataset.id) == expected
      end,
      2000,
      10
    )
  end

  defp get_dataset_preview(dataset_id) do
    body =
      "http://localhost:4000/api/v1/dataset/#{dataset_id}/preview"
      |> HTTPoison.get!()
      |> Map.get(:body)
      |> Jason.decode!()

    case body do
      %{"message" => message} -> message
      %{"data" => data} -> data
    end
  end
end
