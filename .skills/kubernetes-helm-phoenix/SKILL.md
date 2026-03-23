---
name: kubernetes-helm-phoenix
description: Guidelines for integrating Helm package management with Phoenix applications. Covers Helm CLI wrapping, values generation, deployment orchestration, and testing strategies.
---

# Kubernetes Helm Integration for Phoenix

This skill provides patterns for managing Helm deployments from Phoenix applications, enabling programmatic control of Helm releases.

## When to Use This Skill

Use this skill when:
- Your Phoenix app needs to deploy resources to Kubernetes via Helm
- You want to programmatically manage Helm releases
- You need dynamic values generation for Helm charts
- You're building a multi-tenant platform that deploys per-user instances

## Architecture

```
Phoenix App ──► Helm Module ──► Connection Module ──► kubectl ──► Helm ──► Kubernetes
                    │
                    └── Values Generation (Elixir Map → YAML)
                    └── Chart Path Resolution
                    └── Release Management
```

## Installation

Add dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:ymlr, "~> 5.0"}  # YAML encoding for Helm values
  ]
end
```

Install:
```bash
cd apps/platform
mix deps.get
```

## Implementation

### 1. Create Helm Module

Create `lib/my_app/kubernetes/helm.ex`:

```elixir
defmodule MyApp.Kubernetes.Helm do
  @moduledoc """
  Wrapper around Helm CLI for managing chart deployments.
  """

  require Logger

  alias MyApp.Kubernetes.Connection

  # Path to your Helm chart (relative to project root)
  @chart_path Path.join([File.cwd!(), "..", "..", "infrastructure", "helm", "my-chart"])

  @doc """
  Deploys or upgrades a Helm release.
  """
  def upgrade_install(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    values = Keyword.fetch!(opts, :values)
    cluster_id = Keyword.get(opts, :cluster_id, "local")

    # Write values to temporary file
    values_file = write_values_file(values)

    args = [
      "upgrade", "--install", name, @chart_path,
      "--namespace", namespace,
      "--values", values_file,
      "--create-namespace"
    ]

    try do
      case Connection.kubectl(cluster_id, args) do
        {:ok, output} -> {:ok, output}
        {:error, error} -> 
          Logger.error("Helm failed: #{error}")
          {:error, "Deployment failed: #{error}"}
      end
    after
      File.rm(values_file)
    end
  end

  @doc """
  Removes a Helm release.
  """
  def uninstall(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")

    args = ["uninstall", name, "--namespace", namespace]

    case Connection.kubectl(cluster_id, args) do
      {:ok, output} -> {:ok, output}
      {:error, error} -> 
        if String.contains?(error, "not found") do
          {:ok, "Already removed"}
        else
          {:error, error}
        end
    end
  end

  @doc """
  Gets release status as JSON.
  """
  def status(name, opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")

    args = [
      "status", name, 
      "--namespace", namespace,
      "--output", "json"
    ]

    case Connection.kubectl(cluster_id, args) do
      {:ok, output} -> 
        Jason.decode(output)
      {:error, error} -> 
        {:error, error}
    end
  end

  @doc """
  Lists all releases.
  """
  def list(opts \\ []) do
    namespace = Keyword.get(opts, :namespace)
    cluster_id = Keyword.get(opts, :cluster_id, "local")

    args = ["list", "--output", "json"]
    args = if namespace, do: args ++ ["--namespace", namespace], else: args

    case Connection.kubectl(cluster_id, args) do
      {:ok, "[]"} -> {:ok, []}
      {:ok, output} -> Jason.decode(output)
      {:error, error} -> {:error, error}
    end
  end

  # Private functions

  defp write_values_file(values) do
    path = Path.join(System.tmp_dir!(), "helm-values-#{:erlang.unique_integer([:positive])}.yaml")
    yaml = Ymlr.document!(values)
    File.write!(path, yaml)
    path
  end
end
```

### 2. Values Generation

Create a builder function for your specific chart:

```elixir
defmodule MyApp.Helm.Values do
  @moduledoc """
  Builds Helm values for MyApp deployments.
  """

  def build(instance) do
    %{
      instance: %{
        name: instance.name,
        tier: instance.tier
      },
      config: %{
        modelProvider: instance.model_provider,
        defaultModel: instance.default_model
      },
      secrets: build_secrets(instance),
      resources: get_tier_resources(instance.tier)
    }
  end

  defp build_secrets(instance) do
    case instance.model_provider do
      "zai" -> %{zaiApiKey: instance.api_key}
      "anthropic" -> %{anthropicApiKey: instance.api_key}
      _ -> %{}
    end
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

  defp get_tier_resources(_), do: get_tier_resources("starter")
end
```

### 3. Usage in Domain Logic

```elixir
defmodule MyApp.Instances do
  alias MyApp.Kubernetes.Helm
  alias MyApp.Helm.Values

  def provision_instance(instance) do
    values = Values.build(instance)
    
    case Helm.upgrade_install(instance.name,
      namespace: instance.namespace,
      values: values
    ) do
      {:ok, _output} -> {:ok, instance}
      {:error, error} -> {:error, error}
    end
  end

  def destroy_instance(instance) do
    case Helm.uninstall(instance.name,
      namespace: instance.namespace
    ) do
      {:ok, _output} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
```

## Configuration

### coveralls.json

Exclude Helm module from coverage (requires external tools):

```json
{
  "skip_files": [
    "lib/my_app/kubernetes/helm.ex",
    "lib/my_app/kubernetes/connection.ex"
  ]
}
```

### mix.exs

```elixir
def project do
  [
    deps: deps(),
    test_coverage: [tool: ExCoveralls]
  ]
end

defp deps do
  [
    {:ymlr, "~> 5.0"}
  ]
end
```

## Testing Strategy

**DO NOT** write unit tests for Helm module - it requires external kubectl/helm binaries.

**Instead:**
1. **Integration tests** at the domain level
2. **Manual verification** with `iex -S mix`
3. **Mock** in unit tests for other modules

```elixir
# In domain tests, mock the Helm calls
defmodule MyApp.InstancesTest do
  use MyApp.DataCase

  import Mock

  test "provisions instance via Helm" do
    with_mock MyApp.Kubernetes.Helm, [
      upgrade_install: fn _, _ -> {:ok, "deployed"} end
    ] do
      # Test your domain logic
    end
  end
end
```

## Error Handling

Common errors and how to handle them:

| Error | Cause | Solution |
|-------|-------|----------|
| "not found" | Release doesn't exist | Return `{:ok, "already removed"}` for idempotent delete |
| "connection refused" | kubectl can't connect | Check cluster connectivity |
| "YAML parse error" | Invalid values | Validate values before encoding |
| "timed out" | Deployment too slow | Increase timeout option |

## Best Practices

### 1. Always Clean Up Temp Files

```elixir
try do
  # Execute helm command
after
  File.rm(values_file)  # Clean up temp file
end
```

### 2. Use Keyword.fetch! for Required Options

```elixir
namespace = Keyword.fetch!(opts, :namespace)  # Raises if missing
```

### 3. Log Errors at Module Level

```elixir
{:error, error} ->
  Logger.error("Helm failed: #{error}")
  {:error, "Deployment failed: #{error}"}
```

### 4. Handle Idempotent Operations

```elixir
# Uninstall should succeed even if release doesn't exist
case Helm.uninstall(name, opts) do
  {:ok, _} -> :ok
  {:error, error} -> 
    if String.contains?(error, "not found"), do: :ok, else: {:error, error}
end
```

## Verification

Test manually in IEx:

```bash
# Start IEx with Mix
iex -S mix
```

```elixir
# Test values generation
values = MyApp.Helm.Values.build(%{name: "test", tier: "starter"})
IO.inspect(values)

# Test helm list
MyApp.Kubernetes.Helm.list(namespace: "platform")

# Test deployment (requires running cluster)
MyApp.Kubernetes.Helm.upgrade_install("my-release",
  namespace: "default",
  values: values
)
```

## Related Skills

- [kubernetes-phoenix](../kubernetes-phoenix/SKILL.md) - Kubernetes Connection module
- [oban-jobs](../oban-jobs/SKILL.md) - Async job processing
- [ash-resources](../ash-resources/SKILL.md) - Domain modeling

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ymlr Package](https://hex.pm/packages/ymlr)
- [Kubernetes Connection](./kubernetes-phoenix/SKILL.md)
