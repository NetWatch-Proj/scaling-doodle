defmodule ScalingDoodle.Instances.Services.DestroyInstanceService do
  @moduledoc """
  Service module for destroying an OpenClaw instance from Kubernetes.

  This service handles:
  1. Uninstalling the Helm release
  2. Returning success regardless of whether the release existed
  """

  alias ScalingDoodle.Kubernetes.Helm

  require Logger

  @doc """
  Entry point for the service. Destroys an instance from Kubernetes.

  Args should be a map with:
  - `name` - the instance/release name
  - `namespace` - the Kubernetes namespace

  Returns {:ok, output} on success or {:error, reason} on failure.
  """
  @spec call(%{name: String.t(), namespace: String.t()}) ::
          {:ok, String.t()} | {:error, term()}
  def call(%{name: name, namespace: namespace}) do
    Logger.info("Starting destroy for instance #{name}")

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
