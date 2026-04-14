# frozen_string_literal: true

require "test_helper"

class AuthorizedUsersControllerTest < ActionDispatch::IntegrationTest

  test "index requires admin access" do
    sign_in_as(users(:one))

    get authorized_users_path

    assert_redirected_to root_path
  end

  test "admin can create authorized user" do
    sign_in_as(users(:admin))

    assert_difference("AuthorizedUser.count", 1) do
      post authorized_users_path, params: { authorized_user: { email_address: "new@example.com" } }
    end

    assert_redirected_to authorized_users_path
    follow_redirect!
    assert_match "Authorized user added.", response.body
  end

  test "admin can update authorized user" do
    sign_in_as(users(:admin))

    patch authorized_user_path(authorized_users(:one)),
          params: { authorized_user: { email_address: "updated@example.com" } }

    assert_redirected_to authorized_users_path
    assert_equal "updated@example.com", authorized_users(:one).reload.email_address
  end

  test "admin can destroy authorized user" do
    sign_in_as(users(:admin))

    assert_difference("AuthorizedUser.count", -1) do
      delete authorized_user_path(authorized_users(:two))
    end

    assert_redirected_to authorized_users_path
  end

end
