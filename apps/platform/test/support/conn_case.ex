defmodule ScalingDoodleWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ScalingDoodleWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import Phoenix.ConnTest

  # Define endpoint at module level for log_in_user
  @endpoint ScalingDoodleWeb.Endpoint

  using do
    quote do
      use ScalingDoodleWeb, :verified_routes

      # Import conveniences for testing with connections
      import Phoenix.ConnTest
      import Plug.Conn
      import ScalingDoodle.Generator
      import ScalingDoodleWeb.ConnCase

      # Import test data generators

      # The default endpoint for testing
      @endpoint ScalingDoodleWeb.Endpoint
    end
  end

  setup tags do
    ScalingDoodle.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs in a user for testing via magic link.
  """
  def log_in_user(conn, user) do
    token = ScalingDoodle.Generator.magic_link_token(user: user)

    # Simulate visiting the magic link to authenticate
    conn
    |> get("/auth/user/magic_link?token=#{token}")
    |> recycle()
  end
end
