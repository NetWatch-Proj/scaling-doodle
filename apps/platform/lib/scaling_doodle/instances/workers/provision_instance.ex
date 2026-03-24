defmodule ScalingDoodle.Instances.Workers.ProvisionInstance do
  @moduledoc """
  Oban worker for provisioning an OpenClaw instance to Kubernetes.

  This worker:
  1. Generates a gateway token (if not already set)
  2. Updates the instance status to "provisioning"
  3. Deploys the instance using Helm with the generated token
  4. Updates the status to "running" on success or "error" on failure
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60]

  alias ScalingDoodle.Instances.Instance
  alias ScalingDoodle.Kubernetes.Helm

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => instance_id}}) do
    Logger.info("Starting provision for instance #{instance_id}")

    case Ash.get(Instance, instance_id, authorize?: false) do
      {:ok, instance} ->
        # Generate gateway token if not already set
        instance = ensure_gateway_token(instance)

        with {:ok, instance} <- update_status(instance, "provisioning"),
             {:ok, _output} <- deploy_instance(instance),
             {:ok, instance} <- update_status(instance, "running") do
          Logger.info("Instance #{instance_id} provisioned successfully")
          {:ok, instance}
        else
          {:error, error_reason} ->
            Logger.error("Failed to provision instance #{instance_id}: #{inspect(error_reason)}")
            _ignored = update_status(instance, "error")
            {:error, error_reason}
        end

      {:error, reason} ->
        Logger.error("Instance #{instance_id} not found: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_gateway_token(instance) do
    if instance.gateway_token do
      instance
    else
      token = Helm.generate_gateway_token()

      {:ok, updated} =
        Ash.update(instance, %{gateway_token: token}, action: :update_status, authorize?: false)

      updated
    end
  end

  defp update_status(instance, status) do
    Ash.update(instance, %{status: status}, action: :update_status, authorize?: false)
  end

  defp deploy_instance(instance) do
    values = Helm.build_values(instance)

    Helm.upgrade_install(instance.name,
      namespace: instance.namespace,
      values: values,
      timeout: 300,
      wait: true
    )
  end
end
