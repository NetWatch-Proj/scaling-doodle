defmodule ScalingDoodle.Kubernetes.Helm do
  @moduledoc """
  Wrapper around Helm CLI for managing OpenClaw chart deployments.

  This module provides functions to deploy, upgrade, and manage Helm releases
  for OpenClaw instances. It works in conjunction with the Connection module
  to execute Helm commands against the configured Kubernetes cluster.

  ## Usage

      # Deploy or upgrade an instance
      values = %{instance: %{name: "my-openclaw", tier: "starter"}, ...}
      {:ok, output} = Helm.upgrade_install("my-openclaw",
        namespace: "tenant-demo",
        values: values
      )

      # Check release status
      {:ok, status} = Helm.status("my-openclaw", namespace: "tenant-demo")

      # Remove an instance
      {:ok, output} = Helm.uninstall("my-openclaw", namespace: "tenant-demo")

  ## Configuration

  The Helm module uses the same configuration as the Connection module:
  - Local development: Uses kubectl with kubeconfig
  - Production: Uses in-cluster configuration

  The chart path is resolved relative to the project root:
  `infrastructure/kubernetes/helm/openclaw`
  """

  alias ScalingDoodle.Kubernetes.Connection

  require Logger

  @typedoc "Helm release name"
  @type release_name :: String.t()

  @typedoc "Kubernetes namespace"
  @type namespace :: String.t()

  @typedoc "Helm values as Elixir map"
  @type values :: map()

  @typedoc "Options for Helm operations"
  @type opts :: keyword()

  # Chart path - read from config with fallback to env var
  defp chart_path do
    config = Application.get_env(:scaling_doodle, :kubernetes, [])

    Keyword.get(config, :chart_path) ||
      System.get_env("OPENCLAW_CHART_PATH") ||
      default_chart_path()
  end

  defp default_chart_path do
    # Fallback: Try to find it relative to current working directory
    # This works when running from project root
    File.cwd!()
    |> Path.join("infrastructure/kubernetes/helm/openclaw")
    |> Path.expand()
  end

  @doc """
  Deploys or upgrades a Helm release.

  If the release doesn't exist, it will be installed. If it exists,
  it will be upgraded with the new values.

  ## Options

  - `:namespace` - Target namespace (required)
  - `:values` - Map of values to pass to Helm (required)
  - `:cluster_id` - Cluster to deploy to (default: "local")
  - `:timeout` - Timeout in seconds (default: 300)
  - `:wait` - Wait for resources to be ready (default: true)

  ## Examples

      values = %{
        instance: %{name: "my-openclaw", tier: "starter"},
        config: %{defaultModel: "zai/glm-5-turbo"},
        secrets: %{zaiApiKey: "secret-key"}
      }

      {:ok, output} = Helm.upgrade_install("my-openclaw",
        namespace: "tenant-demo",
        values: values
      )
  """
  @spec upgrade_install(release_name(), opts()) :: {:ok, String.t()} | {:error, String.t()}
  def upgrade_install(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    values = Keyword.fetch!(opts, :values)
    cluster_id = Keyword.get(opts, :cluster_id, "local")
    timeout = Keyword.get(opts, :timeout, 300)
    wait = Keyword.get(opts, :wait, true)

    # Write values to temporary file
    values_file = write_values_file(values)

    base_args = [
      "upgrade",
      "--install",
      name,
      chart_path(),
      "--namespace",
      namespace,
      "--values",
      values_file,
      "--timeout",
      "#{timeout}s"
    ]

    with_wait = if wait, do: base_args ++ ["--wait"], else: base_args
    final_args = with_wait ++ ["--create-namespace"]

    try do
      case Connection.helm(cluster_id, final_args) do
        {:ok, output} ->
          {:ok, output}

        {:error, error} ->
          Logger.error("Helm upgrade failed for #{name}: #{error}")
          {:error, "Failed to deploy #{name}: #{error}"}
      end
    after
      File.rm(values_file)
    end
  end

  @doc """
  Removes a Helm release and all associated resources.

  ## Options

  - `:namespace` - Target namespace (required)
  - `:cluster_id` - Cluster to uninstall from (default: "local")
  - `:keep_history` - Keep release history (default: false)

  ## Examples

      {:ok, output} = Helm.uninstall("my-openclaw", namespace: "tenant-demo")
  """
  @spec uninstall(release_name(), opts()) :: {:ok, String.t()} | {:error, String.t()}
  def uninstall(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")
    keep_history = Keyword.get(opts, :keep_history, false)

    base_args = ["uninstall", name, "--namespace", namespace]
    final_args = if keep_history, do: base_args ++ ["--keep-history"], else: base_args

    case Connection.helm(cluster_id, final_args) do
      {:ok, output} ->
        {:ok, output}

      {:error, error} ->
        # Helm returns error if release doesn't exist, which is fine for idempotent delete
        if String.contains?(error, "not found") do
          {:ok, "Release #{name} not found (already removed)"}
        else
          Logger.error("Helm uninstall failed for #{name}: #{error}")
          {:error, "Failed to remove #{name}: #{error}"}
        end
    end
  end

  @doc """
  Gets the status of a Helm release.

  ## Options

  - `:namespace` - Target namespace (required)
  - `:cluster_id` - Cluster to check (default: "local")

  ## Returns

  Returns `{:ok, status_map}` where status_map contains:
  - `:name` - Release name
  - `:namespace` - Release namespace
  - `:status` - Current status (e.g., "deployed", "failed")
  - `:revision` - Current revision number
  - `:updated` - Last update timestamp

  ## Examples

      {:ok, status} = Helm.status("my-openclaw", namespace: "tenant-demo")
      IO.puts("Status: \#{status.status}")
  """
  @spec status(release_name(), opts()) :: {:ok, map()} | {:error, String.t()}
  def status(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")

    args = [
      "status",
      name,
      "--namespace",
      namespace,
      "--output",
      "json"
    ]

    case Connection.helm(cluster_id, args) do
      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, status} ->
            {:ok, parse_status(status)}

          {:error, error} ->
            {:error, "Failed to parse status: #{inspect(error)}"}
        end

      {:error, error} ->
        if String.contains?(error, "not found") do
          {:ok, %{status: "not_found", name: name, namespace: namespace}}
        else
          {:error, "Failed to get status: #{error}"}
        end
    end
  end

  @doc """
  Lists all Helm releases in a namespace.

  ## Options

  - `:namespace` - Target namespace (default: "all")
  - `:cluster_id` - Cluster to list from (default: "local")
  - `:all` - Show all releases including failed (default: false)

  ## Examples

      {:ok, releases} = Helm.list(namespace: "tenant-demo")
      Enum.each(releases, fn r -> IO.puts(r.name) end)
  """
  @spec list(opts()) :: {:ok, list(map())} | {:error, String.t()}
  def list(opts \\ []) do
    namespace = Keyword.get(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")
    all = Keyword.get(opts, :all, false)

    base_args = ["list", "--output", "json"]

    with_namespace =
      if namespace,
        do: base_args ++ ["--namespace", namespace],
        else: base_args ++ ["--all-namespaces"]

    final_args = if all, do: with_namespace ++ ["--all"], else: with_namespace

    case Connection.kubectl(cluster_id, final_args) do
      {:ok, "[]"} ->
        {:ok, []}

      {:ok, output} ->
        case Jason.decode(output) do
          {:ok, releases} when is_list(releases) ->
            {:ok, Enum.map(releases, &parse_release/1)}

          {:error, error} ->
            {:error, "Failed to parse releases: #{inspect(error)}"}
        end

      {:error, error} ->
        {:error, "Failed to list releases: #{error}"}
    end
  end

  @doc """
  Builds Helm values map for an instance.

  This is a convenience function to generate the values structure
  expected by the OpenClaw Helm chart from an Instance struct.

  ## Examples

      values = Helm.build_values(instance)
      {:ok, _} = Helm.upgrade_install(instance.name,
        namespace: instance.namespace,
        values: values
      )
  """
  @spec build_values(map()) :: values()
  def build_values(instance) do
    tier = Map.get(instance, :tier, "standard")
    gateway_token = Map.get(instance, :gateway_token) || generate_gateway_token()

    %{
      instance: %{
        name: instance.name,
        tier: tier
      },
      config: %{
        modelProvider: instance.model_provider,
        defaultModel: instance.default_model
      },
      secrets: build_secrets(instance, gateway_token),
      resources: get_tier_resources(tier)
    }
  end

  @doc """
  Generates a secure random gateway token for OpenClaw.
  """
  @spec generate_gateway_token() :: String.t()
  def generate_gateway_token do
    # Generate a 48-character hex token (24 bytes)
    24
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  # Private functions

  defp write_values_file(values) do
    path = Path.join(System.tmp_dir!(), "helm-values-#{:erlang.unique_integer([:positive])}.yaml")
    yaml = Ymlr.document!(values)
    File.write!(path, yaml)
    path
  end

  defp build_secrets(instance, gateway_token) do
    # Add API key for the selected provider
    api_key_secret =
      case instance.model_provider do
        "zai" -> %{zaiApiKey: instance.api_key}
        "anthropic" -> %{anthropicApiKey: instance.api_key}
        "openai" -> %{openaiApiKey: instance.api_key}
        _other -> %{}
      end

    # Merge with gateway token
    Map.put(api_key_secret, :gatewayToken, gateway_token)
  end

  defp get_tier_resources("starter") do
    %{
      limits: %{cpu: "1", memory: "2Gi"},
      requests: %{cpu: "500m", memory: "1Gi"}
    }
  end

  defp get_tier_resources("pro") do
    %{
      limits: %{cpu: "2", memory: "4Gi"},
      requests: %{cpu: "1", memory: "2Gi"}
    }
  end

  defp get_tier_resources("standard") do
    %{
      limits: %{cpu: "1", memory: "2Gi"},
      requests: %{cpu: "500m", memory: "1Gi"}
    }
  end

  defp get_tier_resources(_other) do
    get_tier_resources("standard")
  end

  defp parse_status(status) do
    %{
      name: status["name"],
      namespace: status["namespace"],
      status: status["info"]["status"],
      revision: status["version"],
      updated: status["info"]["last_deployed"]
    }
  end

  defp parse_release(release) do
    %{
      name: release["name"],
      namespace: release["namespace"],
      revision: release["revision"],
      status: release["status"],
      updated: release["updated"],
      chart: release["chart"],
      app_version: release["app_version"]
    }
  end
end
