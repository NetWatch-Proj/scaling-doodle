defmodule ScalingDoodle.Instances.Services.ProvisionInstanceServiceTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Services.ProvisionInstanceService

  describe "call/1" do
    @tag :capture_log
    test "returns error when instance not found" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, _reason} = ProvisionInstanceService.call(non_existent_id)
    end
  end
end
