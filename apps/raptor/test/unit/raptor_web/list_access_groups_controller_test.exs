defmodule RaptorWeb.ListAccessGroupsControllerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore

  describe "retrieves access groups by dataset_id" do
    test "returns an empty list when there are no access groups for the given dataset", %{conn: conn} do

      dataset_id = "dataset-without-access-groups"
      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)
      expected = %{"access_groups" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given dataset", %{conn: conn} do

      dataset_id = "dataset-without-access-groups"
      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: ["access-group1", "access-group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)
      expected = %{"access_groups" => ["access-group1", "access-group2"]}

      assert actual == expected
    end

  end

  describe "retrieves access groups by user_id" do
    test "returns an empty list when there are no access groups for the given user", %{conn: conn} do

      user_id = "user-without-access-groups"
      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?user_id=#{user_id}")
        |> json_response(200)
      expected = %{"access_groups" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given user", %{conn: conn} do

      user_id = "user-with-access-groups"
      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: ["access-group1", "access-group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?user_id=#{user_id}")
        |> json_response(200)
      expected = %{"access_groups" => ["access-group1", "access-group2"]}

      assert actual == expected
    end

  end

  describe "error scenarios" do
    test "returns a 400 when invalid parameters are passed", %{conn: conn} do

      actual =
        conn
        |> get("/api/listAccessGroups?invalid_parameter=invalid")
        |> json_response(400)
      expected = %{"message" => "dataset_id or user_id must be passed."}

      assert actual == expected
    end
  end
end
