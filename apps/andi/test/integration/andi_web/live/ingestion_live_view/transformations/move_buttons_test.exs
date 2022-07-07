defmodule AndiWeb.IngestionLiveView.Transformations.MoveButtonsTest do

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Checkov
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation

  @url_path "/ingestions/"

  setup %{conn: conn} do
    ingestion = Ingestions.create()
    transform1 = create_transformation_with_name("Black", ingestion)
    transform2 = create_transformation_with_name("Blue", ingestion)
    transform3 = create_transformation_with_name("Green", ingestion)
    transformations = [transform1, transform2, transform3]
    ingestion
      |> Map.merge(%{transformations: transformations})
      |> Ingestions.update()

    {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    %{view: view, html: html, ingestion: ingestion}
  end

  test "has move up and down buttons for each transformation", %{html: html} do
    {:ok, document} = Floki.parse_document(html)
    assert Floki.find(document, ".move-up") |> Enum.count() == 3
    assert Floki.find(document, ".move-down") |> Enum.count() == 3
  end

  @tag :skip
  test "clicking move up slides that transformation up one row", %{view: view, html: html} do
    {:ok, starting_document} = Floki.parse_document(html)
    assert ["Black", "Blue", "Green"] == starting_document
      |> Floki.find(".transformation-name")
      |> Floki.attribute("value")

    {:ok, _, html} = element(view, ".move-up:nth-of-type(2)")
      |> IO.inspect(label: "button")
      |> render_click()

    {:ok, changed_document} = Floki.parse_document(html)
    changed_order_names = Floki.find(changed_document, ".transformation-header-name")
      |> Floki.attribute("value")
    assert ["Black", "Blue", "Green"] == changed_order_names
  end

  defp create_transformation_with_name(name, ingestion) do
    {:ok, transformation} = %Transformation{
      name: name,
      ingestion_id: ingestion.id,
      id: UUID.uuid4()
    }
      |> Transformations.update()
    transformation
  end

end
