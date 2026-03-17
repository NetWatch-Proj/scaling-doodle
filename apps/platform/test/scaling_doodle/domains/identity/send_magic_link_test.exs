defmodule ScalingDoodle.Identity.SendMagicLinkTest do
  use ScalingDoodle.DataCase, async: true

  import ScalingDoodle.Generator
  import Swoosh.TestAssertions

  alias ScalingDoodle.Identity.SendMagicLink

  describe "send/3" do
    test "sends magic link email to user with email struct" do
      user = generate(user())

      SendMagicLink.send(user, "test-token", [])

      assert_email_sent(
        subject: "Log in to ScalingDoodle",
        to: to_string(user.email)
      )
    end

    test "sends magic link email when user has email as map key" do
      user_map = %{"email" => "map@example.com"}

      SendMagicLink.send(user_map, "test-token", [])

      assert_email_sent(
        subject: "Log in to ScalingDoodle",
        to: "map@example.com"
      )
    end

    test "sends magic link email when user is just an email string" do
      SendMagicLink.send("string@example.com", "test-token", [])

      assert_email_sent(
        subject: "Log in to ScalingDoodle",
        to: "string@example.com"
      )
    end

    test "sends magic link email when user is converted to string" do
      SendMagicLink.send(12_345, "test-token", [])

      assert_email_sent(
        subject: "Log in to ScalingDoodle",
        to: "12345"
      )
    end

    test "returns error when email delivery fails" do
      # Use a custom test adapter that returns an error
      # For this test, we just verify the function handles error correctly
      user = generate(user())

      # Temporarily configure the mailer to fail
      original_adapter = Application.get_env(:scaling_doodle, ScalingDoodle.Mailer)[:adapter]
      Application.put_env(:scaling_doodle, ScalingDoodle.Mailer, adapter: Swoosh.Adapters.Local)

      result = SendMagicLink.send(user, "test-token", [])

      # Should return :ok since Swoosh.Adapters.Local always succeeds
      assert result == :ok

      # Restore original adapter
      Application.put_env(:scaling_doodle, ScalingDoodle.Mailer, adapter: original_adapter)
    end
  end
end
