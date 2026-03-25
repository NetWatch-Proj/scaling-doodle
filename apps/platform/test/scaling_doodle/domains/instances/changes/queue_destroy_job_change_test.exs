defmodule ScalingDoodle.Instances.Changes.QueueDestroyJobChangeTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Instance
  alias ScalingDoodle.Instances.Workers.DestroyInstanceWorker

  import ScalingDoodle.Generator

  describe "QueueDestroyJobChange" do
    test "destroys instance which triggers destroy job" do
      user = generate_user()

      attrs = %{
        name: "destroy-test-instance",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # Job is queued but not executed in manual test mode
      assert :ok =
               Ash.destroy(instance, actor: user, authorize?: false)

      # Verify instance is destroyed
      assert {:ok, []} =
               Instance
               |> Ash.Query.for_read(:for_user, %{user_id: user.id})
               |> Ash.read(actor: user, authorize?: false)
    end

    test "worker module is properly configured" do
      # Verify the worker configuration
      assert DestroyInstanceWorker.__opts__()[:max_attempts] == 3
      assert DestroyInstanceWorker.__opts__()[:queue] == :default
    end
  end
end
