defmodule ScalingDoodle.Instances.Instance do
  @moduledoc """
  Represents an OpenClaw instance deployed to Kubernetes.

  Instances are owned by users and deployed to user-specific namespaces
  in the Kubernetes cluster. The provisioning process is handled
  asynchronously via Oban workers.
  """
  use Ash.Resource,
    otp_app: :scaling_doodle,
    domain: ScalingDoodle.Instances,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias ScalingDoodle.Identity.User
  alias ScalingDoodle.Vault.Types.EncryptedBinary

  require Ash.Query

  postgres do
    table "instances"
    repo ScalingDoodle.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :model_provider, :default_model, :api_key]

      argument :user, :struct do
        constraints instance_of: User
        allow_nil? false
      end

      change fn changeset, _context ->
        user = Ash.Changeset.get_argument(changeset, :user)

        changeset
        |> Ash.Changeset.change_attribute(:user_id, user.id)
        |> Ash.Changeset.change_attribute(:status, "pending")
        |> Ash.Changeset.change_attribute(:namespace, "tenant-#{user.id}")
      end

      change relate_actor(:user)
      change ScalingDoodle.Instances.Changes.QueueProvisionJob
    end

    read :for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    update :update_status do
      accept [:status, :gateway_token]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change ScalingDoodle.Instances.Changes.QueueDestroyJob
    end
  end

  policies do
    bypass actor_present() do
      authorize_if always()
    end

    bypass action_type(:read) do
      authorize_if always()
    end
  end

  validations do
    validate one_of(:model_provider, ["zai", "anthropic", "openai"]) do
      on :create
    end

    validate one_of(:status, ["pending", "provisioning", "running", "error"]) do
      on [:create, :update]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 63
      public? true
    end

    attribute :namespace, :string do
      allow_nil? false
      public? true
    end

    attribute :model_provider, :string do
      allow_nil? false
      default "zai"
      public? true
    end

    attribute :default_model, :string do
      allow_nil? false
      constraints min_length: 1
      public? true
    end

    attribute :api_key, EncryptedBinary do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :status, :string do
      allow_nil? false
      default "pending"
      public? true
    end

    attribute :gateway_token, EncryptedBinary do
      allow_nil? true
      sensitive? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, User do
      allow_nil? false
      destination_attribute :id
      attribute_type :uuid
    end
  end

  identities do
    identity :unique_name_per_user, [:name, :user_id]
  end
end
