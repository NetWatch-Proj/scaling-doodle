defmodule ScalingDoodle.MixProject do
  use Mix.Project

  def project do
    [
      app: :scaling_doodle,
      version: "0.0.0",
      elixir: "1.19.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [
          :ex_unit
        ],
        plt_file: {:no_warn, "priv/plts/project.plt"},
        list_unused_filter: true
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ScalingDoodle.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
        precommit: :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bandit, "1.10.3"},
      {:dialyxir, "1.4.7", only: [:dev, :test], runtime: false},
      {:dns_cluster, "0.2.0"},
      {:ecto_sql, "3.13.5"},
      {:esbuild, "0.10.0", runtime: Mix.env() == :dev},
      {:excoveralls, "0.18.5", only: :test},
      {:gettext, "1.0.2"},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth: 1},
      {:jason, "1.4.4"},
      {:lazy_html, "0.1.10", only: :test},
      {:phoenix, "1.8.5"},
      {:phoenix_ecto, "4.7.0"},
      {:phoenix_html, "4.3.0"},
      {:phoenix_live_dashboard, "0.8.7"},
      {:phoenix_live_reload, "1.6.2", only: :dev},
      {:phoenix_live_view, "1.1.26"},
      {:postgrex, "0.22.0"},
      {:req, "0.5.17"},
      {:styler, "1.10.0", only: [:dev, :test], runtime: false},
      {:swoosh, "1.23.0"},
      {:tailwind, "0.4.1", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "1.1.0"},
      {:telemetry_poller, "1.3.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "assets.build": ["compile", "tailwind scaling_doodle", "esbuild scaling_doodle"],
      "assets.deploy": [
        "tailwind scaling_doodle --minify",
        "esbuild scaling_doodle --minify",
        "phx.digest"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      lint: ["format"],
      "lint.ci": ["format --check-formatted"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
