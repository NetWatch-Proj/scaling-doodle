defmodule ScalingDoodleWeb.InstancesLive.IndexTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodleWeb.InstancesLive.Index

  describe "InstancesLive.Index" do
    test "module exists and has required callbacks" do
      assert function_exported?(Index, :mount, 3)
      assert function_exported?(Index, :handle_params, 3)
      assert function_exported?(Index, :handle_event, 3)
      assert function_exported?(Index, :render, 1)
    end
  end
end
