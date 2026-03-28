defmodule ScalingDoodle.Kubernetes.HelmIntegrationTest do
  @moduledoc """
  Integration tests for Helm operations.

  These tests require:
  - kubectl installed and available
  - A running Kubernetes cluster (kind recommended)
  - The OpenClaw Helm chart available

  Run with: mix test --include integration
  """

  use ScalingDoodle.DataCase, async: false

  alias ScalingDoodle.Kubernetes.Helm

  @moduletag :integration

  setup_all do
    # Check prerequisites
    kubectl_available = System.find_executable("kubectl") != nil
    helm_available = System.find_executable("helm") != nil

    if !(kubectl_available and helm_available) do
      raise "kubectl and helm must be installed to run integration tests"
    end

    # Check if we can connect to a cluster
    case System.cmd("kubectl", ["version"], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {_reason, _code} ->
        raise "Cannot connect to Kubernetes cluster. Please ensure a cluster is running."
    end

    :ok
  end

  setup do
    # Create a unique namespace for each test
    namespace = "test-#{System.unique_integer([:positive])}"

    # Create the namespace
    System.cmd("kubectl", ["create", "namespace", namespace], stderr_to_stdout: true)

    on_exit(fn ->
      # Cleanup namespace
      System.cmd("kubectl", ["delete", "namespace", namespace, "--ignore-not-found=true"], stderr_to_stdout: true)
    end)

    {:ok, namespace: namespace}
  end

  describe "Helm integration" do
    test "can generate gateway token", %{namespace: _namespace} do
      token = Helm.generate_gateway_token()

      assert is_binary(token)
      assert byte_size(token) == 48
      assert token =~ ~r/^[a-f0-9]+$/
    end

    test "build_values creates correct structure" do
      instance = %{
        name: "test-instance",
        namespace: "test-ns",
        model_provider: "zai",
        default_model: "glm-5",
        api_key: "test-api-key",
        gateway_token: "test-token"
      }

      values = Helm.build_values(instance)

      assert values.instance.name == "test-instance"
      assert values.instance.tier == "standard"
      assert values.config.modelProvider == "zai"
      assert values.config.defaultModel == "glm-5"
      assert values.secrets.zaiApiKey == "test-api-key"
      assert values.secrets.gatewayToken == "test-token"
      assert is_map(values.resources)
    end

    test "upgrade_install and uninstall work end-to-end", %{namespace: namespace} do
      release_name = "test-release-#{System.unique_integer([:positive])}"

      values = %{
        instance: %{name: release_name, tier: "starter"},
        config: %{modelProvider: "zai", defaultModel: "glm-5"},
        secrets: %{zaiApiKey: "test-key", gatewayToken: "test-token"},
        resources: Helm.build_values(%{}).resources
      }

      # Deploy
      assert {:ok, _output} =
               Helm.upgrade_install(release_name,
                 namespace: namespace,
                 values: values,
                 timeout: 60
               )

      # Verify release exists
      assert {:ok, status} = Helm.status(release_name, namespace: namespace)
      assert status.status in ["deployed", "pending-install"]

      # Uninstall
      assert {:ok, _result} = Helm.uninstall(release_name, namespace: namespace)

      # Verify release is gone
      assert {:ok, %{status: "not_found"}} = Helm.status(release_name, namespace: namespace)
    end
  end
end
