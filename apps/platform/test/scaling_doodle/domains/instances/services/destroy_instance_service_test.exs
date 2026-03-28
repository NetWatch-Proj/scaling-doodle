defmodule ScalingDoodle.Instances.Services.DestroyInstanceServiceTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Services.DestroyInstanceService

  describe "call/1" do
    test "module exists and exports call/1" do
      assert function_exported?(DestroyInstanceService, :call, 1)
    end
  end
end
