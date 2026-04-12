# frozen_string_literal: true

require "test_helper"

class IssuesControllerTest < ActionDispatch::IntegrationTest

  test "show renders basic issue details" do
    sign_in_as(users(:one))

    get issue_path(issues(:one))

    assert_response :success
    assert_match issues(:one).title, response.body
    assert_match projects(:one).name, response.body
    assert_match "Occurrences", response.body
  end

  test "resolve updates issue status" do
    sign_in_as(users(:one))

    patch resolve_issue_path(issues(:one))

    assert_redirected_to issue_path(issues(:one))
    assert_equal "resolved", issues(:one).reload.status
  end

  test "reopen updates issue status" do
    sign_in_as(users(:one))

    patch reopen_issue_path(issues(:two))

    assert_redirected_to issue_path(issues(:two))
    assert_equal "open", issues(:two).reload.status
  end

end
