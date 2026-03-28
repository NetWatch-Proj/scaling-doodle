defmodule ScalingDoodle.Kubernetes.HelmValuesTest do
  @moduledoc """
  Tests for Helm values generation - no Kubernetes required.
  """

  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Kubernetes.Helm

  describe "build_values/1" do
    test "builds complete values structure" do
      instance = %{
        name: "my-instance",
        namespace: "tenant-123",
        model_provider: "zai",
        default_model: "glm-5-turbo",
        api_key: "sk-secret-key",
        gateway_token: "abc123"
      }

      values = Helm.build_values(instance)

      # Instance section
      assert values.instance.name == "my-instance"
      assert values.instance.tier == "standard"

      # Config section
      assert values.config.modelProvider == "zai"
      assert values.config.defaultModel == "glm-5-turbo"

      # Secrets section
      assert values.secrets.zaiApiKey == "sk-secret-key"
      assert values.secrets.gatewayToken == "abc123"

      # Resources section
      assert is_map(values.resources.limits)
      assert is_map(values.resources.requests)
    end

    test "generates gateway token when not provided" do
      instance = %{
        name: "test",
        namespace: "ns",
        model_provider: "anthropic",
        default_model: "claude-opus",
        api_key: "key"
      }

      values = Helm.build_values(instance)

      assert is_binary(values.secrets.gatewayToken)
      assert byte_size(values.secrets.gatewayToken) == 48
    end

    test "uses correct API key field for each provider" do
      base = %{
        name: "test",
        namespace: "ns",
        default_model: "model",
        api_key: "secret-key",
        gateway_token: "token"
      }

      # Z.AI
      zai =
        base
        |> Map.put(:model_provider, "zai")
        |> Helm.build_values()

      assert zai.secrets.zaiApiKey == "secret-key"
      refute Map.has_key?(zai.secrets, :anthropicApiKey)
      refute Map.has_key?(zai.secrets, :openaiApiKey)

      # Anthropic
      anthropic =
        base
        |> Map.put(:model_provider, "anthropic")
        |> Helm.build_values()

      assert anthropic.secrets.anthropicApiKey == "secret-key"
      refute Map.has_key?(anthropic.secrets, :zaiApiKey)
      refute Map.has_key?(anthropic.secrets, :openaiApiKey)

      # OpenAI
      openai =
        base
        |> Map.put(:model_provider, "openai")
        |> Helm.build_values()

      assert openai.secrets.openaiApiKey == "secret-key"
      refute Map.has_key?(openai.secrets, :zaiApiKey)
      refute Map.has_key?(openai.secrets, :anthropicApiKey)
    end

    test "uses default tier when not specified" do
      instance = %{
        name: "test",
        namespace: "ns",
        model_provider: "zai",
        default_model: "model",
        api_key: "key",
        gateway_token: "token"
      }

      values = Helm.build_values(instance)
      assert values.instance.tier == "standard"
    end

    test "accepts custom tier" do
      instance = %{
        name: "test",
        namespace: "ns",
        model_provider: "zai",
        default_model: "model",
        api_key: "key",
        gateway_token: "token",
        tier: "pro"
      }

      values = Helm.build_values(instance)
      assert values.instance.tier == "pro"
    end

    test "includes resource limits for starter tier" do
      instance = %{
        name: "test",
        namespace: "ns",
        model_provider: "zai",
        default_model: "model",
        api_key: "key",
        gateway_token: "token",
        tier: "starter"
      }

      values = Helm.build_values(instance)
      assert values.resources.limits.cpu == "1"
      assert values.resources.limits.memory == "2Gi"
      assert values.resources.requests.cpu == "500m"
      assert values.resources.requests.memory == "1Gi"
    end

    test "includes resource limits for pro tier" do
      instance = %{
        name: "test",
        namespace: "ns",
        model_provider: "zai",
        default_model: "model",
        api_key: "key",
        gateway_token: "token",
        tier: "pro"
      }

      values = Helm.build_values(instance)
      assert values.resources.limits.cpu == "2"
      assert values.resources.limits.memory == "4Gi"
      assert values.resources.requests.cpu == "1"
      assert values.resources.requests.memory == "2Gi"
    end
  end

  describe "generate_gateway_token/0" do
    test "generates unique tokens" do
      tokens = for _i <- 1..10, do: Helm.generate_gateway_token()

      # All tokens should be unique
      assert length(Enum.uniq(tokens)) == 10

      # All tokens should be valid hex
      Enum.each(tokens, fn token ->
        assert token =~ ~r/^[a-f0-9]{48}$/
      end)
    end

    test "generates cryptographically secure tokens" do
      token = Helm.generate_gateway_token()

      # Should be 48 hex characters (24 bytes of entropy)
      assert byte_size(token) == 48

      # Should appear random (not sequential, not repeating)
      refute String.duplicate("a", 48) == token
    end
  end
end
