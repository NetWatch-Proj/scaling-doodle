defmodule ScalingDoodle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    ash_domains = Application.fetch_env!(:scaling_doodle, :ash_domains)
    oban_config = Application.fetch_env!(:scaling_doodle, Oban)

    children = [
      ScalingDoodleWeb.Telemetry,
      ScalingDoodle.Repo,
      {DNSCluster, query: Application.get_env(:scaling_doodle, :dns_cluster_query) || :ignore},
      {Oban, AshOban.config(ash_domains, oban_config)},
      {Phoenix.PubSub, name: ScalingDoodle.PubSub},
      # Start a worker by calling: ScalingDoodle.Worker.start_link(arg)
      # {ScalingDoodle.Worker, arg},
      # Start to serve requests, typically the last entry
      ScalingDoodleWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :scaling_doodle]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ScalingDoodle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    ScalingDoodleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
