defmodule ScalingDoodle.Instances.Services.ProvisionInstanceServiceTest do
  use ScalingDoodle.DataCase, async: true

  import ScalingDoodle.Generator

  alias ScalingDoodle.Instances.Instance
  alias ScalingDoodle.Instances.Services.ProvisionInstanceService

  describe "call/1" do
    @tag :capture_log
    test "returns error when instance not found" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, _reason} = ProvisionInstanceService.call(non_existent_id)
    end

    @tag :capture_log
    test "generates gateway token if not present" do
      user = generate_user()

      attrs = %{
        name: "test-instance-no-token",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # Verify instance was created without token
      refute instance.gateway_token

      # Service will fail at Helm step (no K8s), but token should be generated
      # This tests the ensure_gateway_token logic path
      result = ProvisionInstanceService.call(instance.id)

      # Should fail at Helm deployment step (no Kubernetes), but we verify token was created
      assert {:error, _reason} = result

      # Reload instance to check if token was generated before Helm call
      assert {:ok, updated_instance} =
               Ash.get(Instance, instance.id, actor: user, authorize?: false)

      # Token should have been generated
      assert updated_instance.gateway_token
      assert is_binary(updated_instance.gateway_token)
      assert byte_size(updated_instance.gateway_token) == 48
    end

    @tag :capture_log
    test "uses existing gateway token if already present" do
      user = generate_user()

      attrs = %{
        name: "test-instance-with-token-#{System.unique_integer([:positive])}",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # Set the gateway token via update
      existing_token = "existing-token-12345"

      assert {:ok, instance} =
               Ash.update(instance, %{gateway_token: existing_token},
                 action: :update_status,
                 authorize?: false
               )

      # Verify instance has the token
      assert instance.gateway_token == existing_token

      # Service will fail at Helm step, but token should remain unchanged
      result = ProvisionInstanceService.call(instance.id)
      assert {:error, _reason} = result

      # Reload instance to verify token was not changed
      assert {:ok, updated_instance} =
               Ash.get(Instance, instance.id, actor: user, authorize?: false)

      # Token should remain the same
      assert updated_instance.gateway_token == existing_token
    end

    @tag :capture_log
    test "updates status through provisioning lifecycle" do
      user = generate_user()

      attrs = %{
        name: "test-instance-status",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert instance.status == "pending"

      # Service will fail at Helm step, but should have set provisioning status
      ProvisionInstanceService.call(instance.id)

      # Reload and check status (should be error since Helm failed)
      assert {:ok, updated_instance} =
               Ash.get(Instance, instance.id, actor: user, authorize?: false)

      # Status should be error since Helm deployment failed
      assert updated_instance.status == "error"
    end
  end

  describe "service structure" do
    test "exports call/1 function" do
      assert function_exported?(ProvisionInstanceService, :call, 1)
    end

    test "module has documentation" do
      docs = Code.fetch_docs(ProvisionInstanceService)

      assert match?(
               {:docs_v1, _annotation, _beam_language, _format_version, _module_doc, _metadata, _docs},
               docs
             )
    end
  end
end
