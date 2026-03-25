defmodule ScalingDoodle.KubernetesCase do
  @moduledoc """
  Test case for Kubernetes-related tests.

  Provides helpers for:
  - Mocking kubectl/helm calls
  - Running integration tests against a kind cluster
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import ScalingDoodle.KubernetesCase
    end
  end

  @doc """
  Mocks kubectl to return success without actually running commands.
  Use for unit tests that don't need real Kubernetes.
  """
  def mock_kubectl_success(output \\ "") do
    # In a real implementation, we'd use Mox to mock the Connection module
    # For now, we can test the business logic separately
    {:ok, output}
  end

  @doc """
  Mocks kubectl to simulate a failure.
  """
  def mock_kubectl_failure(error \\ "command failed") do
    {:error, error}
  end

  @doc """
  Checks if we're running in an environment with Kubernetes available.
  """
  def kubernetes_available? do
    System.find_executable("kubectl") != nil
  end

  @doc """
  Checks if a kind cluster is running.
  """
  def kind_cluster_running?(cluster_name \\ "openclaw-platform") do
    case System.cmd("kind", ["get", "clusters"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, cluster_name)
      _ -> false
    end
  end
end
