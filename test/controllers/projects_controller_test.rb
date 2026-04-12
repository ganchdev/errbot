# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest

  test "index requires admin access" do
    sign_in_as(users(:one))

    get projects_path

    assert_redirected_to root_path
  end

  test "admin can create project" do
    sign_in_as(users(:admin))

    assert_difference("Project.count", 1) do
      post projects_path, params: {
        project: {
          name: "Mobile App",
          slug: "mobile-app",
          default_environment: "production"
        }
      }
    end

    assert_redirected_to projects_path
    assert_equal "Mobile App", Project.order(:id).last.name
  end

  test "admin can update project" do
    sign_in_as(users(:admin))

    patch project_path(projects(:one)), params: {
      project: {
        name: "Storefront API v2",
        slug: projects(:one).slug,
        default_environment: "production"
      }
    }

    assert_redirected_to projects_path
    assert_equal "Storefront API v2", projects(:one).reload.name
  end

end
