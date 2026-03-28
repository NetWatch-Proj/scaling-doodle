defmodule ScalingDoodle.Instances.Workers.ProvisionInstanceWorkerTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Workers.ProvisionInstanceWorker

  describe "perform/1" do
    @tag :capture_log
    test "returns error when instance not found" do
      non_existent_id = Ecto.UUID.generate()
      job = %Oban.Job{args: %{"instance_id" => non_existent_id}}

      assert {:error, _reason} = ProvisionInstanceWorker.perform(job)
    end

    test "worker struct has correct configuration" do
      # Verify the worker is configured correctly
      assert ProvisionInstanceWorker.__opts__()[:max_attempts] == 3
      assert ProvisionInstanceWorker.__opts__()[:queue] == :default
      assert ProvisionInstanceWorker.__opts__()[:unique][:period] == 60
    end
  end
end
