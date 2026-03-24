defmodule ScalingDoodle.Instances.Changes.QueueDestroyJob do
  @moduledoc """
  Ash change that queues a destroy job when the instance is deleted.

  The job is queued in an after_transaction hook so it has access to
  the instance data before the record is deleted from the database.
  """
  use Ash.Resource.Change

  alias ScalingDoodle.Instances.Workers.DestroyInstance

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    instance = changeset.data

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      insert_destroy_job(result, instance)
    end)
  end

  defp insert_destroy_job(result, instance) do
    case result do
      :ok ->
        queue_destroy_job(instance)
        result

      {:ok, _deleted_instance} = success ->
        queue_destroy_job(instance)
        success

      error ->
        error
    end
  end

  defp queue_destroy_job(instance) do
    job_result =
      %{
        "instance_id" => instance.id,
        "name" => instance.name,
        "namespace" => instance.namespace
      }
      |> DestroyInstance.new()
      |> Oban.insert()

    case job_result do
      {:ok, job} ->
        Logger.info("Queued destroy job #{job.id} for instance #{instance.id}")

      {:error, reason} ->
        Logger.error("Failed to queue destroy job: #{inspect(reason)}")
    end
  end
end
