defmodule Rambo.Repo.Migrations.CreateTopics do
  use Ecto.Migration

  def change do
    create table(:topics) do
      add :title, :string, null: false
      add :topic_uuid, :uuid, null: false

      timestamps()  # inserted_at와 updated_at 컬럼을 생성
    end

    create unique_index(:topics, [:topic_uuid])
  end
end
