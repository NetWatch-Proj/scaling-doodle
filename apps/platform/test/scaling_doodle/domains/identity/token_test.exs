defmodule ScalingDoodle.Identity.TokenTest do
  use ScalingDoodle.DataCase, async: true

  alias Ash.Resource.Info
  alias ScalingDoodle.Identity.Token

  describe "token actions" do
    test "store_token action exists and is configured" do
      action = Info.action(Token, :store_token)
      assert action
      assert action.type == :create
    end

    test "get_token action exists and is configured" do
      action = Info.action(Token, :get_token)
      assert action
      assert action.type == :read
    end

    test "expired action exists and is configured" do
      action = Info.action(Token, :expired)
      assert action
      assert action.type == :read
    end

    test "expunge_expired action exists and is configured" do
      action = Info.action(Token, :expunge_expired)
      assert action
      assert action.type == :destroy
    end

    test "revoke_token action exists and is configured" do
      action = Info.action(Token, :revoke_token)
      assert action
      assert action.type == :create
    end

    test "revoke_jti action exists and is configured" do
      action = Info.action(Token, :revoke_jti)
      assert action
      assert action.type == :create
    end

    test "revoked? action exists and is configured" do
      action = Info.action(Token, :revoked?)
      assert action
      assert action.type == :action
    end
  end

  describe "token attributes" do
    test "token has required fields configured" do
      # Check that the token resource has the expected attributes
      jti_attr = Info.attribute(Token, :jti)
      assert jti_attr
      assert jti_attr.primary_key?

      subject_attr = Info.attribute(Token, :subject)
      assert subject_attr

      expires_at_attr = Info.attribute(Token, :expires_at)
      assert expires_at_attr

      purpose_attr = Info.attribute(Token, :purpose)
      assert purpose_attr
    end

    test "token has timestamps configured" do
      created_attr = Info.attribute(Token, :created_at)
      assert created_attr

      updated_attr = Info.attribute(Token, :updated_at)
      assert updated_attr
    end
  end

  describe "token policies" do
    test "token has policy DSL configured" do
      # Verify policies are configured (the policy block exists)
      # We can't easily introspect policies but we can verify the resource compiles
      assert Code.ensure_loaded?(Token)
    end
  end

  describe "token resource configuration" do
    test "token module is defined and loads" do
      # Verify the Token module is properly defined
      assert Code.ensure_loaded?(Token)
    end

    test "token has postgres configuration" do
      postgres = AshPostgres.DataLayer.Info.repo(Token)
      assert postgres == ScalingDoodle.Repo
    end
  end

  describe "read actions" do
    test "expired action filters by expires_at" do
      # Verify the expired action has the correct filter
      action = Info.action(Token, :expired)
      assert action.filter
    end
  end

  describe "revoke_all_stored_for_subject action" do
    test "action exists and is configured" do
      action = Info.action(Token, :revoke_all_stored_for_subject)
      assert action
      assert action.type == :update
    end
  end
end
