defmodule ScalingDoodle.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  alias ScalingDoodle.Identity.User

  @spec secret_for([atom()], module(), keyword(), map()) :: {:ok, String.t()} | :error
  def secret_for([:authentication, :tokens, :signing_secret], User, _opts, _context) do
    Application.fetch_env(:scaling_doodle, :token_signing_secret)
  end
end
