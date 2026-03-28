---
name: create-worker-module
description: Create an Oban worker module that delegates to a Service via the standard `call` interface. Use when you need a background job that orchestrates work through a Service module.
metadata:
  category: oban
  related: create-service-module, create-ash-change
---

# Create Worker Module

Create an Oban worker module that delegates to a Service via the standard `call` interface.

## When to use

Use this skill when you need to:
- Create a background job that runs asynchronously
- Process work outside the request/response cycle
- Queue work to run later or retry on failure

## File location

`lib/scaling_doodle/domains/{domain}/workers/{action}_{resource}_worker.ex`

## Module naming

- Must end with `Worker` suffix
- Format: `{Action}{Resource}Worker`
- Examples: `ProvisionInstanceWorker`, `SendEmailWorker`

## Implementation pattern

```elixir
defmodule MyApp.Workers.ProvisionInstanceWorker do
  @moduledoc """
  Oban worker for provisioning an instance.

  Delegates all business logic to ProvisionInstanceService.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60]

  alias MyApp.Services.ProvisionInstanceService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"instance_id" => instance_id}}) do
    Logger.info("ProvisionInstanceWorker started for #{instance_id}")
    ProvisionInstanceService.call(instance_id)
  end
end
```

## Key principles

1. **Thin delegator only** - Just extract args and call Service
2. **Max 15 lines in `perform/1`** - If longer, logic belongs in Service
3. **Must call `Service.call()`** - Not arbitrary functions
4. **No business logic** - No conditionals, no DB calls, no HTTP calls
5. **Log start of work** - Helps with debugging job execution
6. **Return Service result directly** - Don't transform or check it

## Worker configuration

```elixir
use Oban.Worker,
  queue: :default,           # Job queue (default, high, low, background)
  max_attempts: 3,       # Number of retries
  unique: [period: 60]    # Uniqueness window in seconds (optional)
```

## When triggered

Workers are triggered by:
- Ash Change modules (via `Oban.insert()`)
- Direct insertion: `MyWorker.new(args) |> Oban.insert()`
- Scheduled jobs (cron)

## Testing

Create: `test/my_app/workers/provision_instance_worker_test.exs`

```elixir
defmodule MyApp.Workers.ProvisionInstanceWorkerTest do
  use MyApp.DataCase, async: true

  alias MyApp.Workers.ProvisionInstanceWorker

  describe "perform/1" do
    test "calls service with correct args" do
      job = %Oban.Job{args: %{"instance_id" => "123"}}
      assert {:ok, _} = ProvisionInstanceWorker.perform(job)
    end
  end
end
```

## Credo rules enforced

- Module must end with `Worker` suffix
- Max 15 lines in `perform/1`
- Must call `Service.call()` (not arbitrary functions)
- No business logic (no case/cond/with/if-else)
- No direct Ash/Repo/Helm/HTTP calls

## Related skills

- [create-service-module](create-service-module/SKILL.md) - Create the service this worker calls
- [create-ash-change](create-ash-change/SKILL.md) - Create change module that queues this worker
