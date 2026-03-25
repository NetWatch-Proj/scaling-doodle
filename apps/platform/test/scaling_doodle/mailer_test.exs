defmodule ScalingDoodle.MailerTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Mailer

  describe "Mailer" do
    test "module exists" do
      assert Code.ensure_loaded?(Mailer)
    end
  end
end
