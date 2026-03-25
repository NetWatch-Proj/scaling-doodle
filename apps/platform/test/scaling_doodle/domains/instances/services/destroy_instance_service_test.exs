defmodule ScalingDoodle.Instances.Services.DestroyInstanceServiceTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Services.DestroyInstanceService

  describe "destroy/2" do
    test "module exists and exports destroy/2" do
      assert function_exported?(DestroyInstanceService, :destroy, 2)
    end
  end
end
