defmodule Andi.InputSchemas.Ingestions.TransformationTest do
  use ExUnit.Case

  alias Andi.InputSchemas.Ingestions.Transformation

  test "sucessfully validates a valid transformation" do
    changes = %{
      type: "concatenation",
      name: "name",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "separator" => ".",
        "targetField" => "name"
      }
    }

    changeset = Transformation.changeset(changes)

    assert changeset.errors == []
    assert changeset.valid?
  end

  test "fails for an invalid transformation" do
    changes = %{
      type: "concatenation",
      name: "name",
      parameters: %{
        "sourceFields" => ["other", "name"],
        "targetField" => "name"
      }
    }

    changeset = Transformation.changeset(changes)

    assert changeset.errors == [{:parameters, {"Transformation not valid.", []}}]
    assert not changeset.valid?
  end

  test "fails for empty parameters" do
    changes = %{
      type: "concatenation",
      parameters: nil
    }

    changeset = Transformation.changeset(changes)
    assert not changeset.valid?
    assert changeset.errors[:parameters] != nil
    assert {"is required", [validation: :required]} == changeset.errors[:parameters]
  end

  test "fails for invalid type" do
    changes = %{
      type: "invalid",
      parameters: %{}
    }

    changeset = Transformation.changeset(changes)

    assert not changeset.valid?
    assert changeset.errors[:type] != nil
    assert changeset.errors[:type] == {"invalid type: invalid", []}
  end

  test "sucessfully converts a transformation to a changeset" do
    id = UUID.uuid4()
    ingestion_id = UUID.uuid4()
    transformation = %Transformation{id: id, name: "turtle", ingestion_id: ingestion_id}

    changeset = Transformation.convert_andi_transformation_to_changeset(transformation)

    assert %Ecto.Changeset{changes: %{id: ^id, name: "turtle", ingestion_id: ^ingestion_id}} = changeset
  end

  test "sucessfully creates an invalid changeset from form data when there is no transformation type selected" do
    id = UUID.uuid4()

    form_data = %{
      name: "Transformation Name",
      id: id
    }

    changeset = Transformation.changeset_from_form_data(form_data)

    assert %Ecto.Changeset{changes: %{id: ^id, name: "Transformation Name", parameters: %{}}} = changeset
    refute changeset.valid?
    assert changeset.errors == [type: {"is required", [validation: :required]}]
  end

  test "sucessfully creates a valid changeset from form data when there is a transformation type selected" do
    id = UUID.uuid4()

    form_data = %{
      name: "Transformation Name",
      id: id,
      type: "concatenation",
      sourceFields: ["other", "name"],
      separator: ".",
      targetField: "name"
    }

    changeset = Transformation.changeset_from_form_data(form_data) |> IO.inspect(label: "wat")

    assert %Ecto.Changeset{
             changes: %{
               id: ^id,
               name: "Transformation Name",
               type: "concatenation",
               parameters: %{sourceFields: ["other", "name"], separator: ".", targetField: "name"}
             }
           } = changeset

    assert changeset.valid?
    assert changeset.errors == []
  end
end
