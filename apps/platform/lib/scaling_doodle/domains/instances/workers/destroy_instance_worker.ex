defmodule ScalingDoodle.Instances.Workers.DestroyInstanceWorker do
  @moduledoc """
  Oban worker for destroying an OpenClaw instance from Kubernetes.

  This worker delegates all business logic to DestroyInstanceService.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 30]

  alias ScalingDoodle.Instances.Services.DestroyInstanceService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => _instance_id} = args}) do
    name = args["name"]
    namespace = args["namespace"]

    Logger.info("DestroyInstanceWorker started for instance #{name}")
    DestroyInstanceService.call(%{name: name, namespace: namespace})
  end
end
