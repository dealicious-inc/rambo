defmodule Rambo.Repo.Migrations.CreateTalkRooms do
  use Ecto.Migration

  def change do
    create table(:talk_rooms) do
      add :room_type, :string, null: false
      add :name, :string

      timestamps()
    end
  end
end