defmodule Raptor.AuthorizeControllerTest do
    use ExUnit.Case
    use Placebo

    use Tesla
    use Properties, otp_app: :raptor

    import SmartCity.TestHelper, only: [eventually: 1]
    import SmartCity.Event
    alias SmartCity.TestDataGenerator, as: TDG
    alias Raptor.Services.DatasetStore
    alias Raptor.Schemas.Dataset
    alias Raptor.Services.UserOrgAssocStore
    alias Raptor.Schemas.UserOrgAssoc
    alias Raptor.Services.Auth0Management

    @instance_name Raptor.instance_name()

    plug(Tesla.Middleware.BaseUrl, "http://localhost:4001")
    getter(:kafka_broker, generic: true)

    describe "authorize" do

    setup do
        allow(Auth0Management.get_users_by_api_key("fakeApiKey"), return: {:ok, [%{"email_verified" => true, "user_id" => "123" }]})
        :ok
    end

      test "returns is_authorized=false when the user does not have permissions to access the requested dataset" do
        dataset = create_and_send_dataset_event()
        system_name =dataset.technical.systemName

        {:ok, %Tesla.Env{body: body}} = get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}", headers: [{"content-type", "application/json"}])

        assert body == "{\"is_authorized\":false}"

      end

      test "returns is_authorized=true when the user has permissions to access the requested dataset" do
        dataset = create_and_send_dataset_event()
        system_name =dataset.technical.systemName
        send_user_org_associate_event(dataset.technical.orgId, "123", "nicole@starfleet.com")

        {:ok, %Tesla.Env{body: body}} = get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}", headers: [{"content-type", "application/json"}])

        assert body == "{\"is_authorized\":true}"

      end

      test "returns is_authorized=false when the user's permissions to access the requested dataset are revoked" do
        dataset = create_and_send_dataset_event()
        system_name =dataset.technical.systemName
        send_user_org_associate_event(dataset.technical.orgId, "123", "nicole@starfleet.com")
        {:ok, %Tesla.Env{body: body}} = get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}", headers: [{"content-type", "application/json"}])
        assert body == "{\"is_authorized\":true}"
        send_user_org_disassociate_event(dataset.technical.orgId, "123")

        {:ok, %Tesla.Env{body: body}} = get("/api/authorize?apiKey=fakeApiKey&systemName=#{system_name}", headers: [{"content-type", "application/json"}])

        assert body == "{\"is_authorized\":false}"

      end
    end

    def create_and_send_dataset_event() do
        dataset = TDG.create_dataset(%{})
        Brook.Event.send(@instance_name, dataset_update(), :test, dataset)

        expected_raptor_dataset =%Dataset{dataset_id: dataset.id, org_id: dataset.technical.orgId, system_name: dataset.technical.systemName}
        eventually(fn ->
            raptor_dataset = DatasetStore.get(dataset.technical.systemName)
            assert raptor_dataset == expected_raptor_dataset
        end)
        dataset
    end

    def send_user_org_disassociate_event(org_id, subject_id) do
        disassociation = %SmartCity.UserOrganizationDisassociate{org_id: org_id, subject_id: subject_id}
        Brook.Event.send(Raptor.instance_name(), user_organization_disassociate(), :testing, disassociation)

        eventually(fn ->
            raptor_user_org_assoc = UserOrgAssocStore.get(subject_id, org_id)
            assert %{} == raptor_user_org_assoc
        end)
    end

    def send_user_org_associate_event(org_id, subject_id, email) do
        association = %SmartCity.UserOrganizationAssociate{org_id: org_id, subject_id: subject_id, email: email}
        Brook.Event.send(Raptor.instance_name(), user_organization_associate(), :testing, association)

        expected_raptor_assoc =%UserOrgAssoc{user_id: subject_id, org_id: org_id, email: email}
        eventually(fn ->
            raptor_user_org_assoc = UserOrgAssocStore.get(subject_id, org_id)
            assert expected_raptor_assoc == raptor_user_org_assoc
        end)
    end
  end
