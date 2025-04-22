defmodule Rambo.Repo.Migrations.CreateTalkRoomUsers do
  use Ecto.Migration

  def change do
    create table(:talk_room_users) do
      add :talk_room_id, references(:talk_rooms, on_delete: :delete_all), null: false
      add :user_id, :bigint, null: false

      add :joined_at, :naive_datetime, null: false, default: fragment("now()")
      add :last_read_message_key, :string  # e.g., "MSG#1710000123456"

      timestamps()
    end

    create index(:talk_room_users, [:talk_room_id])
    create index(:talk_room_users, [:user_id])
    create unique_index(:talk_room_users, [:talk_room_id, :user_id])
  end
end