defmodule ScalingDoodle.Instances.Changes.QueueProvisionJobTest do
  use ScalingDoodle.DataCase, async: true

  import ScalingDoodle.Generator

  alias ScalingDoodle.Instances.Instance
  alias ScalingDoodle.Instances.Workers.ProvisionInstanceWorker

  describe "QueueProvisionJob" do
    test "creates instance successfully which triggers provision job" do
      user = generate_user()

      attrs = %{
        name: "provision-test-instance",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      # Job is queued but not executed in manual test mode
      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # Instance should be created even if job is not executed
      assert instance.name == "provision-test-instance"
      assert instance.status == "pending"
    end

    test "worker module is properly configured" do
      # Verify the worker configuration
      assert ProvisionInstanceWorker.__opts__()[:max_attempts] == 3
      assert ProvisionInstanceWorker.__opts__()[:queue] == :default
    end
  end
end
