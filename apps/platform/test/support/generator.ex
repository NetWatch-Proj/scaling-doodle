defmodule ScalingDoodle.Generator do
  @moduledoc """
  Test data generators using Ash.Generator.

  Usage in tests:

      import ScalingDoodle.Generator

      test "something" do
        user = generate(user())
        # or with overrides
        admin = generate(user(email: "admin@example.com"))
      end
  """
  use Ash.Generator

  alias ScalingDoodle.Identity
  alias ScalingDoodle.Identity.User

  @doc """
  Generates a User with default random data.

  ## Options

    * `:email` - Override the email address (default: auto-generated unique email)
  """
  def user(opts \\ []) do
    changeset_generator(
      User,
      :create,
      defaults: [
        email: sequence(:user_email, &"user#{&1}@example.com")
      ],
      overrides: opts,
      domain: Identity,
      authorize?: false
    )
  end

  @doc """
  Generates a magic link token for a user.

  ## Options

    * `:user` - The user to generate the token for (default: generates a new user)
    * `:email` - Override the user's email (only used if :user not provided)
  """
  def magic_link_token(opts \\ []) do
    user = opts[:user] || generate(user(Keyword.take(opts, [:email])))

    strategy = AshAuthentication.Info.strategy!(User, :magic_link)

    {:ok, token} =
      AshAuthentication.Strategy.MagicLink.request_token_for(
        strategy,
        user,
        []
      )

    token
  end
end
