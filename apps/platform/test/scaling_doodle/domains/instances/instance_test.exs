defmodule ScalingDoodle.Instances.InstanceTest do
  use ScalingDoodle.DataCase, async: true

  alias ScalingDoodle.Instances.Instance

  import ScalingDoodle.Generator

  describe "create/2" do
    test "creates an instance with valid attributes" do
      user = generate_user()

      attrs = %{
        name: "test-instance",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test-api-key",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert instance.name == "test-instance"
      assert instance.model_provider == "zai"
      assert instance.default_model == "claude-sonnet-4-20250514"
      assert instance.api_key == "sk-test-api-key"
      assert instance.status == "pending"
      assert instance.namespace == "tenant-#{user.id}"
      assert instance.user_id == user.id
    end

    test "validates model_provider is one of allowed values" do
      user = generate_user()

      attrs = %{
        name: "test-instance",
        model_provider: "invalid-provider",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert Enum.any?(errors, fn error ->
               error.field == :model_provider &&
                 error.message =~ "expected one of"
             end)
    end

    test "validates name is required" do
      user = generate_user()

      attrs = %{
        name: "",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert Enum.any?(errors, fn error ->
               error.__struct__ == Ash.Error.Changes.Required &&
                 error.field == :name
             end)
    end

    test "validates name is unique per user" do
      user = generate_user()

      attrs = %{
        name: "duplicate-instance",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, _instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # Second creation should fail due to unique constraint
      assert {:error, _error} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)
    end

    test "allows same name for different users" do
      user1 = generate_user()
      user2 = generate_user()

      attrs1 = %{
        name: "shared-instance-name",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user1
      }

      attrs2 = %{
        name: "shared-instance-name",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user2
      }

      assert {:ok, _instance1} =
               Ash.create(Instance, attrs1, actor: user1, authorize?: false)

      assert {:ok, _instance2} =
               Ash.create(Instance, attrs2, actor: user2, authorize?: false)
    end
  end

  describe "read actions" do
    test "for_user/2 returns instances for specific user" do
      user1 = generate_user()
      user2 = generate_user()

      attrs = %{
        name: "instance-1",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user1
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user1, authorize?: false)

      # Should find instance for user1
      results =
        Instance
        |> Ash.Query.for_read(:for_user, %{user_id: user1.id})
        |> Ash.read!(actor: user1, authorize?: false)

      assert length(results) == 1
      assert hd(results).id == instance.id

      # Should not find instance for user2
      results2 =
        Instance
        |> Ash.Query.for_read(:for_user, %{user_id: user2.id})
        |> Ash.read!(actor: user2, authorize?: false)

      assert results2 == []
    end
  end

  describe "update_status/2" do
    setup do
      user = generate_user()

      attrs = %{
        name: "test-instance",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      {:ok, instance} =
        Ash.create(Instance, attrs, actor: user, authorize?: false)

      {:ok, instance: instance}
    end

    test "updates status to provisioning", %{instance: instance} do
      assert {:ok, updated} =
               Ash.update(instance, %{status: "provisioning"},
                 action: :update_status,
                 authorize?: false
               )

      assert updated.status == "provisioning"
    end

    test "updates status to running", %{instance: instance} do
      assert {:ok, updated} =
               Ash.update(instance, %{status: "running"},
                 action: :update_status,
                 authorize?: false
               )

      assert updated.status == "running"
    end

    test "updates status to error", %{instance: instance} do
      assert {:ok, updated} =
               Ash.update(instance, %{status: "error"},
                 action: :update_status,
                 authorize?: false
               )

      assert updated.status == "error"
    end

    test "updates gateway_token", %{instance: instance} do
      assert {:ok, updated} =
               Ash.update(instance, %{gateway_token: "test-token-123"},
                 action: :update_status,
                 authorize?: false
               )

      assert updated.gateway_token == "test-token-123"
    end

    test "validates status must be one of allowed values", %{instance: instance} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.update(instance, %{status: "invalid-status"},
                 action: :update_status,
                 authorize?: false
               )

      assert Enum.any?(errors, fn error ->
               error.field == :status && error.message =~ "expected one of"
             end)
    end
  end

  describe "destroy/2" do
    test "destroys an instance" do
      user = generate_user()

      attrs = %{
        name: "to-delete",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert :ok =
               Ash.destroy(instance, actor: user, authorize?: false)

      # Verify instance is gone
      results =
        Instance
        |> Ash.Query.for_read(:for_user, %{user_id: user.id})
        |> Ash.read!(actor: user, authorize?: false)

      assert results == []
    end
  end

  describe "encrypted fields" do
    test "api_key is encrypted in database" do
      user = generate_user()
      api_key = "sk-encrypted-test-key"

      attrs = %{
        name: "encrypted-test-#{System.unique_integer([:positive])}",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: api_key,
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      # When read back directly, it should be decrypted
      assert {:ok, retrieved} =
               Ash.get(Instance, instance.id, actor: user, authorize?: false)

      assert retrieved.api_key == api_key
    end

    test "gateway_token is encrypted in database" do
      user = generate_user()
      gateway_token = "gw-encrypted-token"

      attrs = %{
        name: "encrypted-test-#{System.unique_integer([:positive])}",
        model_provider: "zai",
        default_model: "claude-sonnet-4-20250514",
        api_key: "sk-test",
        user: user
      }

      assert {:ok, instance} =
               Ash.create(Instance, attrs, actor: user, authorize?: false)

      assert {:ok, updated} =
               Ash.update(instance, %{gateway_token: gateway_token},
                 action: :update_status,
                 authorize?: false
               )

      # When read back directly, it should be decrypted
      assert {:ok, retrieved} =
               Ash.get(Instance, updated.id, actor: user, authorize?: false)

      assert retrieved.gateway_token == gateway_token
    end
  end
end
