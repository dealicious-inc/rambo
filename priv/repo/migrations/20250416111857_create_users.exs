defmodule Rambo.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :username, :string, null: false

      timestamps()  # inserted_at와 updated_at 컬럼을 생성
    end

    create unique_index(:users, [:username])
  end
end
