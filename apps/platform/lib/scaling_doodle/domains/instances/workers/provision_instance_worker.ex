defmodule ScalingDoodle.Instances.Workers.ProvisionInstanceWorker do
  @moduledoc """
  Oban worker for provisioning an OpenClaw instance to Kubernetes.

  This worker delegates all business logic to ProvisionInstanceService.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60]

  alias ScalingDoodle.Instances.Services.ProvisionInstanceService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => instance_id}}) do
    Logger.info("ProvisionInstanceWorker started for instance #{instance_id}")
    ProvisionInstanceService.call(instance_id)
  end
end
