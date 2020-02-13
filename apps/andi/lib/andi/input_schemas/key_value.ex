defmodule Andi.InputSchemas.KeyValue do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, Ecto.UUID)
    field(:key, :string)
    field(:value, :string)
  end

  def changeset(key_value, changes) do
    with_id = Map.put_new(changes, :id, Ecto.UUID.generate())

    key_value
    |> cast(with_id, [:id, :key, :value], empty_values: [])
    # TODO: value should not be required
    |> validate_required([:id, :key, :value])
  end
end
