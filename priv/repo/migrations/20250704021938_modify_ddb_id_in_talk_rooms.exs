defmodule Rambo.Repo.Migrations.ModifyDdbIdInTalkRooms do
  use Ecto.Migration

  def change do
    alter table(:talk_rooms) do
      modify :ddb_id, :string, null: true
    end
  end
end
