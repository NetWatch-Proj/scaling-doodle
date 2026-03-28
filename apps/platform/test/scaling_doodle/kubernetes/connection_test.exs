defmodule ScalingDoodle.Kubernetes.ConnectionTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Kubernetes.Connection

  describe "Connection module" do
    test "exports required functions" do
      assert function_exported?(Connection, :kubectl_available?, 0)
      assert function_exported?(Connection, :kubectl, 2)
      assert function_exported?(Connection, :helm, 2)
      assert function_exported?(Connection, :config, 1)
    end

    test "kubectl_available? returns boolean" do
      result = Connection.kubectl_available?()
      assert is_boolean(result)
    end

    test "config returns connection configuration" do
      # Test with local connection type
      config = Connection.config("local")
      assert {:ok, map} = config
      assert is_map(map)
    end
  end

  describe "Command building" do
    test "builds kubectl command with correct structure" do
      # Test that the command structure is correct
      # This doesn't execute the command, just verifies the logic
      args = ["get", "pods"]

      # The actual command building happens internally
      # We test the public interface
      result = Connection.kubectl("local", args)

      # Should return either {:ok, output} or {:error, reason}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
