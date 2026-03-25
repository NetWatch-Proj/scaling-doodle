defmodule ScalingDoodle.IdentityTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Identity

  describe "Identity domain" do
    test "module exists" do
      assert Code.ensure_loaded?(Identity)
    end
  end
end
