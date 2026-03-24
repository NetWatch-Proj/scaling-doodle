defmodule ScalingDoodle.Repo.Migrations.CreateInstancesTable do
  @moduledoc """
  Creates the instances table for OpenClaw instances.
  """
  use Ecto.Migration

  def up do
    create table(:instances, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:namespace, :string, null: false)
      add(:model_provider, :string, null: false, default: "zai")
      add(:default_model, :string, null: false)
      add(:api_key, :binary, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:user_id, :uuid, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:instances, [:name, :user_id]))
    create(index(:instances, [:user_id]))
    create(index(:instances, [:status]))
  end

  def down do
    drop(table(:instances))
  end
end
