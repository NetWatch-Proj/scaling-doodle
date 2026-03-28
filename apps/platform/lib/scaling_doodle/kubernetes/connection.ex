defmodule ScalingDoodle.Kubernetes.Connection do
  @moduledoc """
  Manages Kubernetes cluster connections across environments.

  Supports:
  - External connections (local dev with kind): Phoenix runs locally, uses kubectl
  - In-cluster connections (production): Phoenix runs in Kubernetes, uses ServiceAccount
  - Multi-cluster connections (future): OIDC or kubeconfig per cluster

  Design principle: Always accept a cluster identifier to support
  multi-cluster architecture from day one.

  ## Cluster Identifiers

  - `"local"` - Local development with kind cluster (default)
  - `"in-cluster"` - Phoenix running inside the same Kubernetes cluster
  - Any other string - Looked up from cluster registry (future multi-cluster support)

  ## Configuration

  ### Local Development (config/dev.exs)

      config :scaling_doodle, :kubernetes,
        connection_type: :external,
        kubeconfig_path: "~/.kube/config",
        context: "kind-openclaw-platform"

  ### Production In-Cluster (config/runtime.exs)

      config :scaling_doodle, :kubernetes,
        connection_type: :in_cluster

  ## Usage Examples

      # Get connection config for local development
      Connection.config("local")

      # Get connection config for in-cluster deployment
      Connection.config("in-cluster")

      # Future: Get config for specific customer cluster
      Connection.config("eks-us-west-2")
  """

  require Logger

  @typedoc "Connection configuration for a cluster"
  @type config :: %{
          type: :external | :in_cluster | :registry,
          cluster_id: String.t(),
          kubeconfig: String.t() | nil,
          context: String.t() | nil,
          host: String.t() | nil,
          ca_cert_path: String.t() | nil,
          token_path: String.t() | nil
        }

  @doc """
  Returns connection configuration for the specified cluster.

  ## Parameters
  - cluster_id: "local" for dev, "in-cluster" for same cluster,
                or registry ID for external clusters

  ## Examples

      # Local development with kind
      Connection.config("local")

      # In-cluster (same cluster as Phoenix)
      Connection.config("in-cluster")

      # Future: External cluster (production multi-cluster)
      Connection.config("eks-us-west-2")
  """
  @spec config(String.t()) :: {:ok, config()} | {:error, String.t()}
  def config(cluster_id \\ "local") do
    case cluster_id do
      "in-cluster" ->
        {:ok, in_cluster_config(cluster_id)}

      "local" ->
        {:ok, external_config(cluster_id)}

      _other ->
        # Future: Load from ClusterRegistry
        {:error, "Multi-cluster support not yet implemented. Use 'local' or 'in-cluster'."}
    end
  end

  @doc """
  Executes a kubectl command against the specified cluster.

  ## Parameters
  - cluster_id: The cluster to execute against
  - args: List of kubectl arguments
  - opts: Options passed to System.cmd/3

  ## Examples

      Connection.kubectl("local", ["get", "nodes"])
      Connection.kubectl("local", ["get", "pods", "-n", "platform"])
  """
  @spec kubectl(String.t(), list(String.t()), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def kubectl(cluster_id, args, opts \\ []) do
    with {:ok, config} <- config(cluster_id),
         {:ok, cmd_args} <- build_kubectl_args(config, args) do
      execute_kubectl(cmd_args, opts)
    end
  end

  @doc """
  Executes a helm command against the specified cluster.

  ## Parameters
  - cluster_id: The cluster to execute against
  - args: List of helm arguments (subcommand and flags)
  - opts: Options passed to System.cmd/3

  ## Examples

      Connection.helm("local", ["upgrade", "--install", "my-release", "./chart"])
      Connection.helm("local", ["list", "-n", "platform"])
  """
  @spec helm(String.t(), list(String.t()), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def helm(cluster_id, args, opts \\ []) do
    with {:ok, config} <- config(cluster_id),
         {:ok, cmd_args} <- build_helm_args(config, args) do
      execute_helm(cmd_args, opts)
    end
  end

  @doc """
  Checks if kubectl is available in the system PATH.
  """
  @spec kubectl_available?() :: boolean()
  def kubectl_available? do
    case System.cmd("which", ["kubectl"], stderr_to_stdout: true) do
      {_output, 0} -> true
      {_error, _exit_code} -> false
    end
  end

  @doc """
  Returns the current kubectl context (useful for debugging).
  """
  @spec current_context() :: {:ok, String.t()} | {:error, String.t()}
  def current_context do
    case System.cmd("kubectl", ["config", "current-context"], stderr_to_stdout: true) do
      {context, 0} -> {:ok, String.trim(context)}
      {error, _exit_code} -> {:error, String.trim(error)}
    end
  end

  # Private functions

  defp in_cluster_config(cluster_id) do
    %{
      type: :in_cluster,
      cluster_id: cluster_id,
      # k8s library reads these automatically from service account
      host: "https://kubernetes.default.svc",
      ca_cert_path: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
      token_path: "/var/run/secrets/kubernetes.io/serviceaccount/token",
      kubeconfig: nil,
      context: nil
    }
  end

  defp external_config(cluster_id) do
    k8s_config = Application.get_env(:scaling_doodle, :kubernetes, [])

    %{
      type: :external,
      cluster_id: cluster_id,
      kubeconfig: Keyword.get(k8s_config, :kubeconfig_path, "~/.kube/config"),
      context:
        Keyword.get(
          k8s_config,
          :context,
          System.get_env("KUBE_CONTEXT", "kind-openclaw-platform")
        ),
      host: nil,
      ca_cert_path: nil,
      token_path: nil
    }
  end

  defp build_kubectl_args(config, args) do
    case config.type do
      :external ->
        base_args =
          if config.kubeconfig do
            ["--kubeconfig", Path.expand(config.kubeconfig)]
          else
            []
          end

        context_args =
          if config.context do
            ["--context", config.context]
          else
            []
          end

        {:ok, base_args ++ context_args ++ args}

      :in_cluster ->
        # For in-cluster, kubectl uses the service account automatically
        # if KUBERNETES_SERVICE_HOST and KUBERNETES_SERVICE_PORT are set
        {:ok, args}
    end
  end

  defp build_helm_args(config, args) do
    case config.type do
      :external ->
        # Helm uses KUBECONFIG environment variable or --kubeconfig flag
        # The flag must come AFTER the subcommand
        kubeconfig_args =
          if config.kubeconfig do
            ["--kubeconfig", Path.expand(config.kubeconfig)]
          else
            []
          end

        context_args =
          if config.context do
            ["--kube-context", config.context]
          else
            []
          end

        {:ok, args ++ kubeconfig_args ++ context_args}

      :in_cluster ->
        # For in-cluster, helm uses the service account automatically
        {:ok, args}
    end
  end

  defp execute_kubectl(args, opts) do
    merged_opts = Keyword.merge([stderr_to_stdout: true], opts)

    case System.cmd("kubectl", args, merged_opts) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {error, exit_code} ->
        Logger.error("kubectl failed with exit code #{exit_code}: #{error}")
        {:error, "kubectl command failed (exit #{exit_code}): #{String.trim(error)}"}
    end
  end

  defp execute_helm(args, opts) do
    merged_opts = Keyword.merge([stderr_to_stdout: true], opts)

    case System.cmd("helm", args, merged_opts) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {error, exit_code} ->
        Logger.error("helm failed with exit code #{exit_code}: #{error}")
        {:error, "helm command failed (exit #{exit_code}): #{String.trim(error)}"}
    end
  end
end
