defmodule ScalingDoodleWeb.AuthOverridesTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodleWeb.AuthOverrides

  describe "AuthOverrides" do
    test "module exists" do
      assert Code.ensure_loaded?(AuthOverrides)
    end
  end
end
