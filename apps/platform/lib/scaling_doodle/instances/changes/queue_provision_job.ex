defmodule ScalingDoodle.Instances.Changes.QueueProvisionJob do
  @moduledoc """
  Ash change that queues a provision job after the instance is created.
  """
  use Ash.Resource.Change

  alias ScalingDoodle.Instances.Workers.ProvisionInstance

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &insert_provision_job/2)
  end

  defp insert_provision_job(_changeset, result) do
    case result do
      {:ok, instance} ->
        job_result =
          %{"instance_id" => instance.id}
          |> ProvisionInstance.new()
          |> Oban.insert()

        case job_result do
          {:ok, job} ->
            Logger.info("Queued provision job #{job.id} for instance #{instance.id}")

          {:error, reason} ->
            Logger.error("Failed to queue provision job: #{inspect(reason)}")
        end

        {:ok, instance}

      error ->
        error
    end
  end
end
