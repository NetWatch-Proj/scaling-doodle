defmodule ScalingDoodle.Instances.Workers.DestroyInstance do
  @moduledoc """
  Oban worker for destroying an OpenClaw instance from Kubernetes.

  This worker:
  1. Uninstalls the Helm release
  2. Returns success regardless of whether the release existed
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 30]

  alias ScalingDoodle.Kubernetes.Helm

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => instance_id} = args}) do
    name = args["name"]
    namespace = args["namespace"]

    Logger.info("Starting destroy for instance #{instance_id} (#{name})")

    case Helm.uninstall(name, namespace: namespace) do
      {:ok, output} ->
        Logger.info("Instance #{name} uninstalled successfully: #{output}")
        {:ok, output}

      {:error, reason} ->
        Logger.warning("Failed to uninstall instance #{name}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
