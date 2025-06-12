defmodule Rambo.Repo.Migrations.AddLastActivityAtToTalkRooms do
  use Ecto.Migration

  def change do
    alter table(:talk_rooms) do
      add :last_activity_at, :utc_datetime
    end
  end
end
