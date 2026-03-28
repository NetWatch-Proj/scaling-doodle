defmodule ScalingDoodle.InstancesTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances

  describe "Instances domain" do
    test "module exists" do
      assert Code.ensure_loaded?(Instances)
    end
  end
end
