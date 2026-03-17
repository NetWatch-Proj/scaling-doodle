defmodule ScalingDoodle.Identity.User do
  @moduledoc false
  use Ash.Resource,
    otp_app: :scaling_doodle,
    domain: ScalingDoodle.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        # require_interaction? true  # Temporarily disabled for testing

        sender ScalingDoodle.Identity.SendMagicLink
      end
    end

    tokens do
      enabled? true
      token_resource ScalingDoodle.Identity.Token
      signing_secret ScalingDoodle.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end
  end

  postgres do
    table "users"
    repo ScalingDoodle.Repo
  end

  actions do
    defaults [:read, create: [:email]]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
