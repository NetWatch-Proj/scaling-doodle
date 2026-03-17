defmodule ScalingDoodle.Accounts do
  @moduledoc false
  use Ash.Domain, otp_app: :scaling_doodle, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource ScalingDoodle.Accounts.Token
    resource ScalingDoodle.Accounts.User
  end
end
