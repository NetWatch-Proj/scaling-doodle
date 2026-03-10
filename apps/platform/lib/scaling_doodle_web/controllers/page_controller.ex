defmodule ScalingDoodleWeb.PageController do
  use ScalingDoodleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
