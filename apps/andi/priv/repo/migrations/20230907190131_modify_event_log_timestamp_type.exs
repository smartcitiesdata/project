defmodule Andi.Repo.Migrations.ModifyEventLogTimestampType do
  use Ecto.Migration

  def change do
    IO.inspect("running migration")
    alter table(:event_log) do
      modify :timestamp, :utc_datetime_usec, from: :utc_datetime
    end
  end
end
