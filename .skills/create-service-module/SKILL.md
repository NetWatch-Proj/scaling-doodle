---
name: create-service-module
description: Create a Service module that encapsulates business logic with a standard `call` interface. Use when you need to implement business logic that can be called from workers, controllers, or other contexts.
metadata:
  category: architecture
  related: create-worker-module, create-async-feature
---

# Create Service Module

Create a Service module that encapsulates business logic with a standard `call` interface.

## When to use

Use this skill when you need to:
- Implement business logic that can be called from multiple contexts
- Orchestrate multiple operations (DB, external APIs, etc.)
- Create reusable business logic that doesn't depend on job infrastructure

## File location

`lib/scaling_doodle/domains/{domain}/services/{action}_{resource}_service.ex`

## Module naming

- Must end with `Service` suffix
- Format: `{Action}{Resource}Service`
- Examples: `ProvisionInstanceService`, `DestroyInstanceService`

## Implementation pattern

```elixir
defmodule MyApp.Services.ProvisionInstanceService do
  @moduledoc """
  Service module for provisioning an instance.
  """

  alias MyApp.Repo
  alias MyApp.Instances.Instance

  require Logger

  @doc """
  Entry point for the service.

  Returns {:ok, result} on success or {:error, reason} on failure.
  """
  @spec call(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def call(instance_id) do
    case Repo.get(Instance, instance_id) do
      nil ->
        {:error, :not_found}

      instance ->
        do_provision(instance)
    end
  end

  defp do_provision(instance) do
    with {:ok, step1} <- step_one(instance),
         {:ok, step2} <- step_two(step1) do
      {:ok, step2}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp step_one(instance) do
    # Implementation
    {:ok, instance}
  end

  defp step_two(instance) do
    # Implementation
    {:ok, instance}
  end
end
```

## Key principles

1. **Single public function: `call/1`** - One entry point for all callers
2. **Accepts simple types or maps** - String, integer, or map of args
3. **Returns `{:ok, result}` or `{:error, reason}`** - Consistent return pattern
4. **Private functions for implementation** - Hide complexity
5. **Contains all business logic** - DB calls, external APIs, conditionals
6. **Logger at top** - Use for operational logging

## When called from workers

Workers should call it like this:

```elixir
def perform(%Oban.Job{args: %{"instance_id" => id}}) do
  ProvisionInstanceService.call(id)
end
```

## Testing

Create: `test/my_app/services/provision_instance_service_test.exs`

```elixir
defmodule MyApp.Services.ProvisionInstanceServiceTest do
  use MyApp.DataCase, async: true

  alias MyApp.Services.ProvisionInstanceService

  describe "call/1" do
    test "provisions instance successfully" do
      instance = insert!(:instance)
      assert {:ok, result} = ProvisionInstanceService.call(instance.id)
    end

    test "returns error for non-existent instance" do
      assert {:error, :not_found} = ProvisionInstanceService.call("invalid-id")
    end
  end
end
```

## Credo rules enforced

- Module must end with `Service` suffix
- Must define `call/1` function

## Related skills

- [create-worker-module](create-worker-module/SKILL.md) - Create worker that calls this service
- [create-async-feature](create-async-feature/SKILL.md) - Complete async flow with change, worker, and service
