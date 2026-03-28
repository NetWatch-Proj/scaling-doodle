defmodule ScalingDoodle.Instances.Services.ProvisionInstanceService do
  @moduledoc """
  Service module for provisioning an OpenClaw instance to Kubernetes.

  This service handles:
  1. Fetching the instance from the database
  2. Generating a gateway token (if not already set)
  3. Updating the instance status to "provisioning"
  4. Deploying the instance using Helm
  5. Updating the status to "running" on success or "error" on failure
  """

  alias ScalingDoodle.Instances.Instance
  alias ScalingDoodle.Kubernetes.Helm

  require Logger

  @doc """
  Entry point for the service. Provisions an instance to Kubernetes.

  Returns {:ok, instance} on success or {:error, reason} on failure.
  """
  @spec call(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def call(instance_id) do
    case Ash.get(Instance, instance_id, authorize?: false) do
      {:ok, instance} ->
        do_provision(instance)

      {:error, reason} ->
        Logger.error("Instance #{instance_id} not found: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_provision(instance) do
    instance = ensure_gateway_token(instance)

    with {:ok, instance} <- update_status(instance, "provisioning"),
         {:ok, _output} <- deploy_instance(instance),
         {:ok, instance} <- update_status(instance, "running") do
      Logger.info("Instance #{instance.id} provisioned successfully")
      {:ok, instance}
    else
      {:error, error_reason} ->
        Logger.error("Failed to provision instance #{instance.id}: #{inspect(error_reason)}")
        _ignored = update_status(instance, "error")
        {:error, error_reason}
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
