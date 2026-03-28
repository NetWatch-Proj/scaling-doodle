---
name: create-async-feature
description: Create a complete async feature with Change → Worker → Service pattern. Use when building end-to-end background job functionality triggered by Ash resource actions.
metadata:
  category: workflow
  related: create-ash-change, create-worker-module, create-service-module
---

# Create Async Feature

Create a complete async feature with Change → Worker → Service pattern.

## When to use

Use this skill when you need to:
- Build complete background job functionality
- Trigger async work from Ash resource actions
- Create a full Change → Worker → Service flow

## Creates 3 files

1. **Change** - Queues job after resource action
2. **Worker** - Oban job that delegates to Service  
3. **Service** - Business logic implementation

## Example: Provision Instance

### 1. Change Module

File: `lib/my_app/instances/changes/queue_provision_job_change.ex`

```elixir
defmodule MyApp.Instances.Changes.QueueProvisionJobChange do
  @moduledoc """
  Queues a provision job after instance creation.
  """
  use Ash.Resource.Change

  alias MyApp.Workers.ProvisionInstanceWorker

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &insert_job/2)
  end

  defp insert_job(_changeset, result) do
    case result do
      {:ok, instance} ->
        job_result =
          %{"instance_id" => instance.id}
          |> ProvisionInstanceWorker.new()
          |> Oban.insert()

        case job_result do
          {:ok, job} -> Logger.info("Queued job #{job.id}")
          {:error, reason} -> Logger.error("Failed: #{inspect(reason)}")
        end
        {:ok, instance}
      error -> error
    end
  end
end
```

### 2. Worker Module

File: `lib/my_app/instances/workers/provision_instance_worker.ex`

```elixir
defmodule MyApp.Workers.ProvisionInstanceWorker do
  @moduledoc """
  Oban worker for provisioning instances.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60]

  alias MyApp.Services.ProvisionInstanceService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => instance_id}}) do
    Logger.info("Worker started for #{instance_id}")
    ProvisionInstanceService.call(instance_id)
  end
end
```

### 3. Service Module

File: `lib/my_app/instances/services/provision_instance_service.ex`

```elixir
defmodule MyApp.Services.ProvisionInstanceService do
  @moduledoc """
  Service for provisioning instances.
  """

  require Logger

  @spec call(String.t()) :: {:ok, term()} | {:error, term()}
  def call(instance_id) do
    # All business logic here
    {:ok, result}
  end
end
```

## Flow diagram

```
User creates record
    ↓
Ash Resource (e.g., create action)
    ↓
Change Module (after_transaction)
    ↓
Oban.insert() → Job queued
    ↓
Worker.perform() (called by Oban)
    ↓
Service.call() → Business logic
    ↓
External calls (Helm, API, DB)
```

## Resource integration

```elixir
defmodule MyApp.Instances.Instance do
  use Ash.Resource

  actions do
    create :create do
      primary? true
      change(QueueProvisionJobChange)
    end
  end
end
```

## Testing

Create 3 test files:

1. `test/my_app/changes/queue_provision_job_change_test.exs`
2. `test/my_app/workers/provision_instance_worker_test.exs`
3. `test/my_app/services/provision_instance_service_test.exs`

## Credo rules applied

- Change module ends with `Change`
- Worker module ends with `Worker`
- Service module ends with `Service`
- Worker max 15 lines in perform
- Worker calls `Service.call()`
- Service defines `call` function
- No business logic in workers

## File structure

```
lib/my_app/domains/{domain}/
├── changes/
│   └── queue_{action}_job_change.ex
├── workers/
│   └── {action}_{resource}_worker.ex
└── services/
    └── {action}_{resource}_service.ex
```

## Related skills

- [create-ash-change](create-ash-change/SKILL.md) - Create just the Change module
- [create-worker-module](create-worker-module/SKILL.md) - Create just the Worker module
- [create-service-module](create-service-module/SKILL.md) - Create just the Service module
