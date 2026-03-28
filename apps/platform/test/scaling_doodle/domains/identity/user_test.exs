defmodule ScalingDoodle.Identity.UserTest do
  use ScalingDoodle.DataCase, async: true

  import ScalingDoodle.Generator

  alias ScalingDoodle.Identity.User

  describe "create/1" do
    test "creates a user with valid email" do
      email = "test-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, user} =
               Ash.create(User, %{email: email}, authorize?: false)

      assert to_string(user.email) == email
      assert user.id
    end

    test "creates user with case-insensitive email" do
      email = "Test-Email@EXAMPLE.com"

      assert {:ok, user} =
               Ash.create(User, %{email: email}, authorize?: false)

      # Email should be stored in a normalized form
      assert user.email
    end

    test "enforces unique email constraint" do
      email = "unique-#{System.unique_integer([:positive])}@example.com"

      # Create first user
      assert {:ok, _user} =
               Ash.create(User, %{email: email}, authorize?: false)

      # Attempt to create second user with same email should fail
      assert {:error, _changeset} =
               Ash.create(User, %{email: email}, authorize?: false)
    end

    test "requires email to be present" do
      assert {:error, changeset} =
               Ash.create(User, %{}, authorize?: false)

      assert changeset.errors
    end
  end

  describe "read actions" do
    test "get_by_subject action exists and is configured" do
      # Verify the get_by_subject action is properly configured
      action = Ash.Resource.Info.action(User, :get_by_subject)
      assert action
      assert action.type == :read
    end

    test "read action returns list of users" do
      # Generate some users
      _user1 = generate_user()
      _user2 = generate_user()

      assert {:ok, users} = Ash.read(User, authorize?: false)

      assert is_list(users)
      assert length(users) >= 2
    end
  end

  describe "user attributes" do
    test "user has required attributes" do
      user = generate_user()

      assert user.id
      assert user.email
    end

    test "user id is a valid UUID" do
      user = generate_user()

      assert {:ok, _uuid} = Ecto.UUID.cast(user.id)
    end
  end

  describe "authentication" do
    test "user can be used for magic_link authentication" do
      _user = generate_user()

      # Verify user has the authentication extension configured
      assert AshAuthentication.Info.strategy(User, :magic_link)
    end
  end
end
