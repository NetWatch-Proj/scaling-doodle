defmodule ScalingDoodle.Identity do
  @moduledoc false
  use Ash.Domain, otp_app: :scaling_doodle, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource ScalingDoodle.Identity.Token
    resource ScalingDoodle.Identity.User
  end
end
