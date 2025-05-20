defmodule Rambo.Repo.Migrations.AddDdbIdToTalkRooms do
  use Ecto.Migration

  def change do
    alter table(:talk_rooms) do
      add :ddb_id, :string, null: false, default: ""
    end

    create unique_index(:talk_rooms, [:ddb_id])
  end
end