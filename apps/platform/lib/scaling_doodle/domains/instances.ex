defmodule ScalingDoodle.Instances do
  @moduledoc """
  Domain for managing OpenClaw instances.

  Provides functionality to create, read, update, and delete instances,
  with automatic provisioning to Kubernetes via Oban workers.
  """
  use Ash.Domain, otp_app: :scaling_doodle

  resources do
    resource ScalingDoodle.Instances.Instance do
      define :create_instance, action: :create
      define :list_instances_for_user, action: :for_user, args: [:user_id]
      define :get_instance, action: :read, get_by: [:id]
      define :update_instance_status, action: :update_status
      define :destroy_instance, action: :destroy
    end
  end
end
