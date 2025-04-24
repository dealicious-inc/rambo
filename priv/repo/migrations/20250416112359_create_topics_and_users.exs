defmodule Rambo.Repo.Migrations.CreateTopicsAndUsers do
  use Ecto.Migration

  def change do
    create table(:topics_and_users) do
      add :topic_id, :bigint, null: false
      add :user_id, :bigint, null: false

      timestamps()
    end

    create unique_index(:topics_and_users, [:topic_id, :user_id])

  end
end
