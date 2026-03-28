defmodule ScalingDoodle.Instances.Workers.DestroyInstanceWorkerTest do
  @moduledoc """
  Tests for DestroyInstanceWorker.
  """

  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Workers.DestroyInstanceWorker

  describe "worker configuration" do
    test "has correct max_attempts" do
      assert DestroyInstanceWorker.__opts__()[:max_attempts] == 3
    end

    test "uses default queue" do
      assert DestroyInstanceWorker.__opts__()[:queue] == :default
    end
  end
end
