defmodule ScalingDoodle.Repo do
  use Ecto.Repo,
    otp_app: :scaling_doodle,
    adapter: Ecto.Adapters.Postgres
end
