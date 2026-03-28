---
name: create-ash-change
description: Create an Ash.Resource.Change module that queues an Oban job after a resource action. Use when you need to trigger background jobs from Ash resource lifecycle events.
metadata:
  category: ash
  related: create-worker-module, create-service-module
---

# Create Ash Resource Change

Create an Ash.Resource.Change module that queues an Oban job after a resource action completes successfully.

## When to use

Use this skill when you need to:
- Queue a background job after creating a record
- Queue cleanup after deleting a record  
- Trigger async processing on resource changes

## File location

`lib/scaling_doodle/domains/{domain}/changes/queue_{action}_{resource}_change.ex`

## Module naming

- Must end with `Change` suffix
- Format: `Queue{Action}{Resource}Change`
- Examples: `QueueProvisionJobChange`, `QueueDestroyJobChange`

## Implementation pattern

```elixir
defmodule MyApp.Changes.QueueProvisionJobChange do
  @moduledoc """
  Ash change that queues a provision job after the instance is created.
  """
  use Ash.Resource.Change

  alias MyApp.Workers.ProvisionWorker

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &insert_job/2)
  end

  defp insert_job(_changeset, result) do
    case result do
      {:ok, record} ->
        job_result =
          %{"id" => record.id}
          |> ProvisionWorker.new()
          |> Oban.insert()

        case job_result do
          {:ok, job} ->
            Logger.info("Queued job #{job.id} for #{record.id}")

          {:error, reason} ->
            Logger.error("Failed to queue: #{inspect(reason)}")
        end

        {:ok, record}

      error ->
        error
    end
  end
end
```

## Key principles

1. **Always use `after_transaction`** - Only queue job after DB commit succeeds
2. **Pattern match on result** - Handle both success `{:ok, record}` and errors
3. **Always return original result** - Don't modify the success/error tuple
4. **Log both outcomes** - Success and failure should be logged
5. **Keep it thin** - Just queue the job, no business logic

## Resource integration

Add to your resource action:

```elixir
create :create do
  primary? true
  change(QueueProvisionJobChange)
end
```

## Testing

Create: `test/my_app/changes/queue_provision_job_change_test.exs`

```elixir
defmodule MyApp.Changes.QueueProvisionJobChangeTest do
  use MyApp.DataCase, async: true

  alias MyApp.Changes.QueueProvisionJobChange

  test "queues job on successful create" do
    # Verify job is queued in Oban
  end
end
```

## Credo rules enforced

- Module must end with `Change` suffix
- Must use `after_transaction` pattern

## Related skills

- [create-worker-module](create-worker-module/SKILL.md) - Create the worker this change queues
- [create-service-module](create-service-module/SKILL.md) - Create the service the worker calls
