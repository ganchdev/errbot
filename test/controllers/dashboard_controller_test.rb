# frozen_string_literal: true

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest

  test "signed in users can view issues dashboard" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_match "All issues", response.body
    assert_match issues(:one).title, response.body
    assert_match issues(:two).title, response.body
    assert_match "cursor-pointer rounded-full bg-[#FF3300]", response.body
    assert_match "cursor-pointer w-full rounded-2xl border border-zinc-300 bg-white px-4 py-3", response.body
  end

  test "dashboard filters issues by environment" do
    sign_in_as(users(:one))

    get root_path, params: { environment: "production" }

    assert_response :success
    assert_match issues(:one).title, response.body
    assert_no_match issues(:two).title, response.body
  end

end
