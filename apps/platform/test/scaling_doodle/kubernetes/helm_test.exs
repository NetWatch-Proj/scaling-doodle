defmodule ScalingDoodle.Kubernetes.HelmTest do
  @moduledoc """
  Tests for Helm module without requiring Kubernetes.
  """

  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Kubernetes.Helm

  describe "generate_gateway_token/0" do
    test "generates unique tokens" do
      token1 = Helm.generate_gateway_token()
      token2 = Helm.generate_gateway_token()

      assert is_binary(token1)
      assert is_binary(token2)
      assert token1 != token2
      assert token1 =~ ~r/^[a-f0-9]+$/
    end

    test "generates 48-character hex strings" do
      token = Helm.generate_gateway_token()
      assert byte_size(token) == 48
      assert token =~ ~r/^[a-f0-9]{48}$/
    end
  end
end
