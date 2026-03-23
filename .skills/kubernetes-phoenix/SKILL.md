---
name: kubernetes-phoenix
description: Guidelines for connecting Phoenix applications to Kubernetes clusters for managing external resources. Covers multi-cluster architecture, kubectl integration, ServiceAccount authentication, and local development with kind.
---

# Kubernetes-Phoenix Integration

This skill provides patterns for connecting Phoenix applications to Kubernetes clusters, supporting both local development and production multi-cluster architectures.

## When to Use This Skill

Use this skill when:
- Building a Phoenix app that needs to manage Kubernetes resources
- Creating multi-cluster management interfaces
- Setting up local development with kind clusters
- Implementing Kubernetes authentication (kubectl vs ServiceAccount)

## Architecture Patterns

### Multi-Cluster Design

```
┌─────────────────────────────────────────────────────────────┐
│                     PLATFORM CLUSTER                         │
│  ┌─────────────────┐         ┌─────────────────────────┐   │
│  │   Phoenix App   │────────►│   Cluster Registry      │   │
│  │   (Port 8080)   │  OIDC   │   (Connection Configs)  │   │
│  └─────────────────┘         └─────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ OIDC Authentication
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  EKS Cluster │ │  GKE Cluster │ │  AKS Cluster │
│   (AWS)      │ │   (GCP)      │ │  (Azure)     │
└──────────────┘ └──────────────┘ └──────────────┘
```

**Key Components:**
- Platform cluster runs Phoenix and stores cluster connection configs
- Customer clusters run tenant workloads (e.g., OpenClaw instances)
- OIDC for secure cross-cluster authentication (future)
- Kubeconfig for local development

### Connection Module Pattern

Create a `Kubernetes.Connection` module that abstracts different connection methods:

```elixir
defmodule MyApp.Kubernetes.Connection do
  @moduledoc """
  Manages Kubernetes cluster connections across environments.
  """

  @doc """
  Returns connection config for the specified cluster.
  """
  def config(cluster_id \\ "local") do
    case cluster_id do
      "in-cluster" -> {:ok, in_cluster_config(cluster_id)}
      "local" -> {:ok, external_config(cluster_id)}
      _other -> load_from_registry(cluster_id)
    end
  end

  @doc """
  Executes kubectl command against specified cluster.
  """
  def kubectl(cluster_id, args, opts \\ []) do
    with {:ok, config} <- config(cluster_id),
         {:ok, cmd_args} <- build_kubectl_args(config, args) do
      execute_kubectl(cmd_args, opts)
    end
  end

  defp in_cluster_config(cluster_id) do
    %{
      type: :in_cluster,
      cluster_id: cluster_id,
      host: "https://kubernetes.default.svc",
      ca_cert_path: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
      token_path: "/var/run/secrets/kubernetes.io/serviceaccount/token"
    }
  end

  defp external_config(cluster_id) do
    k8s_config = Application.get_env(:my_app, :kubernetes, [])
    
    %{
      type: :external,
      cluster_id: cluster_id,
      kubeconfig: Keyword.get(k8s_config, :kubeconfig_path, "~/.kube/config"),
      context: Keyword.get(k8s_config, :context, "kind-cluster")
    }
  end
end
```

## Configuration

### Local Development (config/dev.exs)

```elixir
config :my_app, :kubernetes,
  connection_type: :external,
  kubeconfig_path: "~/.kube/config",
  context: "kind-my-cluster"
```

### Production (config/runtime.exs)

```elixir
config :my_app, :kubernetes,
  connection_type: :in_cluster
```

## Local Development Setup

### Prerequisites
- Docker
- kind (Kubernetes in Docker)
- kubectl
- Helm (optional)

### Setup Script Pattern

Create `scripts/setup-local-dev.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up local development environment..."

# Create kind cluster if not exists
if ! kind get clusters | grep -q "my-cluster"; then
  kind create cluster --config infrastructure/kind/config.yaml
fi

# Deploy base infrastructure
kubectl apply -k infrastructure/kubernetes/kustomize/overlays/local

# Wait for dependencies
kubectl wait --for=condition=ready pod -l app=postgres -n platform --timeout=120s

echo "Setup complete!"
echo "  kubectl port-forward svc/postgres 5432:5432 -n platform"
echo "  mix phx.server"
```

## RBAC Configuration

Create `infrastructure/kubernetes/kustomize/base/rbac.yaml`:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: platform-controller
  namespace: platform
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-controller
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "create", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets", "persistentvolumeclaims"]
    verbs: ["get", "list", "create", "update", "delete"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-controller
subjects:
  - kind: ServiceAccount
    name: platform-controller
    namespace: platform
```

## Testing Strategy

**Important:** Tests requiring kubectl should be:
1. Tagged with `@tag :requires_kubectl`
2. Excluded in `test_helper.exs` when kubectl unavailable
3. Or excluded from coveralls.json

**test_helper.exs:**
```elixir
kubectl_available = System.cmd("which", ["kubectl"]) |> elem(1) == 0
exclude_tags = if kubectl_available, do: [], else: [requires_kubectl: true]

ExUnit.start(exclude: exclude_tags)
```

**coveralls.json:**
```json
{
  "skip_files": [
    "lib/my_app/kubernetes/connection.ex"
  ]
}
```

## Common Commands

```bash
# Check connection
kubectl cluster-info

# View resources
kubectl get nodes
kubectl get pods -n platform

# Port-forward database
kubectl port-forward svc/postgres 5432:5432 -n platform

# View logs
kubectl logs -n platform -l app=my-app

# Apply manifests
kubectl apply -k infrastructure/kubernetes/kustomize/overlays/local
```

## Production Considerations

### Multi-Cluster Authentication

**Future Implementation:**
- OIDC tokens for cross-cluster authentication
- Cluster registry in database (cluster_id, endpoint, auth_config)
- Short-lived tokens (no long-lived kubeconfig files)

### Security

- ServiceAccount tokens mounted automatically in pods
- RBAC restricts permissions to required resources only
- OIDC preferred over static kubeconfig files

## Dependencies

Add to `mix.exs`:
```elixir
defp deps do
  [
    # Kubernetes client (optional, for in-cluster)
    {:k8s, "~> 2.0"},
    # YAML encoding (for Helm values)
    {:ymlr, "~> 5.0"}
  ]
end
```

## References

- [kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
