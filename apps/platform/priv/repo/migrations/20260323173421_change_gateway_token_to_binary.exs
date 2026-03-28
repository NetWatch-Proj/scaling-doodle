defmodule ScalingDoodle.Repo.Migrations.ChangeGatewayTokenToBinary do
  @moduledoc """
  Changes gateway_token column from string to binary for encrypted storage.
  """
  use Ecto.Migration

  def up do
    # Drop and recreate as binary since we can't cast string to bytea
    alter table(:instances) do
      remove(:gateway_token)
    end

    alter table(:instances) do
      add(:gateway_token, :binary)
    end
  end

  def down do
    alter table(:instances) do
      remove(:gateway_token)
    end

    alter table(:instances) do
      add(:gateway_token, :string)
    end
  end
end
