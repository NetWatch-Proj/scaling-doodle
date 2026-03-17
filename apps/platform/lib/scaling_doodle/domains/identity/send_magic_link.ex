defmodule ScalingDoodle.Identity.SendMagicLink do
  @moduledoc """
  Sends a magic link email to the user.
  """
  use AshAuthentication.Sender

  import Swoosh.Email

  alias ScalingDoodle.Mailer

  require Logger

  @impl AshAuthentication.Sender
  def send(user, token, _opts) do
    email = get_email(user)

    Logger.debug("Magic link for #{email}: http://localhost:4000/auth/user/magic_link?token=#{token}")

    email_msg =
      new()
      |> from({"ScalingDoodle", "noreply@example.com"})
      |> to(to_string(email))
      |> subject("Log in to ScalingDoodle")
      |> html_body("""
      <h1>Welcome to ScalingDoodle!</h1>
      <p>Click the link below to sign in:</p>
      <p><a href="http://localhost:4000/auth/user/magic_link?token=#{token}">Sign in</a></p>
      """)
      |> text_body("""
      Welcome to ScalingDoodle!

      Copy and paste this link into your browser to sign in:
      http://localhost:4000/auth/user/magic_link?token=#{token}
      """)

    case Mailer.deliver(email_msg) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_email(%{email: email}), do: email
  defp get_email(%{"email" => email}), do: email
  defp get_email(email) when is_binary(email), do: email
  defp get_email(other), do: to_string(other)
end
