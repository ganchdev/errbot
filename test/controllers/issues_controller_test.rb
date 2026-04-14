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

  test "show renders issue toggle with stacktrace and latest event frames content" do
    sign_in_as(users(:one))

    get issue_path(issues(:one))

    assert_response :success
    assert_match "Stacktrace", response.body
    assert_match "Frames", response.body
    assert_match "Event JSON", response.body
    assert_match "From the most recent event at", response.body
    assert_match event_json_issue_path(issues(:one)), response.body
    assert_match issues(:one).culprit, response.body
    assert_match "app/services/checkout.rb", response.body
    assert_match "app/services/checkout.rb in call at line 42", response.body
    assert_match "order.user.id", response.body
    assert_match "41", response.body
    assert_match "42", response.body
    assert_match "43", response.body
    assert_match "stacktrace", response.body
    assert_match "frames", response.body
    assert_match "cursor-pointer rounded-full bg-emerald-600", response.body
    assert_match "cursor-pointer rounded-full bg-zinc-900", response.body
    assert_match "cursor-pointer rounded-full px-4 py-2 text-sm font-semibold transition", response.body
    assert_match "cursor-pointer rounded-full border border-zinc-300 px-4 py-2 text-sm font-medium", response.body
  end

  test "event_json renders latest event payload without app layout" do
    sign_in_as(users(:one))

    get event_json_issue_path(issues(:one))

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]
    assert_match "\"event_id\": \"event-one\"", response.body
    refute_match "<html", response.body
    refute_match "Logout", response.body
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
