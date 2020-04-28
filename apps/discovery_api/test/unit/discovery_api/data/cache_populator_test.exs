defmodule DiscoveryApi.Data.CachePopulatorTest do
  @moduledoc false
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Test.Helper

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.CachePopulator
  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApi.Search.DatasetIndex, as: DatasetSearchIndex

  @instance DiscoveryApi.instance()

  describe "init/1" do
    test "Populates the cache with existing view state models" do
      allow(DatasetSearchIndex.replace_all(any()), return: {:ok, :yarp})

      Helper.clear_saved_models()

      organization = %{} |> TDG.create_organization()

      model =
        Helper.sample_model(%{
          title: "Bob is the man",
          organizationDetails: organization |> Map.from_struct()
        })

      Brook.Test.with_event(@instance, fn ->
        Brook.ViewState.merge(:models, model.id, model)
      end)

      start_supervised!(CachePopulator)

      SmartCity.TestHelper.eventually(fn ->
        assert SystemNameCache.get(organization.orgName, model.name) == model.id
        assert {"bob", model.id} in :ets.lookup(DiscoveryApi.Search.Storage, "bob")
      end)

      assert_called DatasetSearchIndex.replace_all([model])
    end
  end
end
