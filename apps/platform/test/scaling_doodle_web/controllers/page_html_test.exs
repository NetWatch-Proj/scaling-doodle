defmodule ScalingDoodleWeb.PageHTMLTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodleWeb.PageHTML

  describe "PageHTML" do
    test "module exists" do
      assert Code.ensure_loaded?(PageHTML)
    end
  end
end
