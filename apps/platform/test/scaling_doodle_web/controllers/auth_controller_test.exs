defmodule ScalingDoodleWeb.AuthControllerTest do
  use ScalingDoodleWeb.ConnCase, async: true

  describe "authentication happy path" do
    test "unauthenticated user sees Sign In button on home page", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Sign In"
      refute html_response(conn, 200) =~ "Sign Out"
    end

    test "user can view sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/sign-in")
      # The sign-in page is a LiveView with "Sign In" text
      assert html_response(conn, 200) =~ "Sign In"
    end

    test "user can sign in with magic link", %{conn: conn} do
      email = "test@example.com"

      # Create user and generate magic link token using our generator
      user = generate(user(email: email))
      token = magic_link_token(user: user)

      # Sign in with the token
      conn = get(conn, ~p"/auth/user/magic_link?token=#{token}")

      # Should redirect to home page after successful sign in
      assert redirected_to(conn) == ~p"/"

      # Follow redirect and verify user is signed in
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "Sign Out"
      assert html_response(conn, 200) =~ email
    end

    test "user can sign out", %{conn: conn} do
      email = "signout@example.com"

      # Create user and sign in via magic link
      user = generate(user(email: email))
      token = magic_link_token(user: user)

      # Sign in with the token
      conn = get(conn, ~p"/auth/user/magic_link?token=#{token}")

      # Verify sign in worked
      assert redirected_to(conn) == ~p"/"

      # Follow the redirect and verify we're signed in
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "Sign Out"

      # Sign out
      conn = get(recycle(conn), ~p"/sign-out")
      assert redirected_to(conn) == ~p"/"

      # Verify user is signed out
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "Sign In"
    end

    test "invalid magic link token shows error", %{conn: conn} do
      # Try to sign in with an invalid token
      conn = get(conn, ~p"/auth/user/magic_link?token=invalid_token")

      # Should redirect to sign-in page with error
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "multiple users can sign in independently", %{conn: conn} do
      # Generate multiple users with auto-generated unique emails
      [user1, user2] = generate_many(user(), 2)

      # User 1 signs in
      token1 = magic_link_token(user: user1)
      conn = get(conn, ~p"/auth/user/magic_link?token=#{token1}")
      assert redirected_to(conn) == ~p"/"

      # Verify user1 is signed in
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ to_string(user1.email)

      # User 1 signs out
      conn = get(recycle(conn), ~p"/sign-out")

      # User 2 signs in
      token2 = magic_link_token(user: user2)
      conn = get(recycle(conn), ~p"/auth/user/magic_link?token=#{token2}")
      assert redirected_to(conn) == ~p"/"

      # Verify user2 is signed in
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ to_string(user2.email)
    end
  end
end
