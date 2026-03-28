defmodule ScalingDoodle.Repo.Migrations.AddGatewayTokenToInstances do
  @moduledoc """
  Adds gateway_token column to instances table for storing OpenClaw gateway tokens.
  """
  use Ecto.Migration

  def up do
    alter table(:instances) do
      add(:gateway_token, :string)
    end
  end

  def down do
    alter table(:instances) do
      remove(:gateway_token)
    end
  end
end
