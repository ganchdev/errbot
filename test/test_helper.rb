# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

  end
end

module AuthenticationTestHelper

  def sign_in_as(user)
    session = user.sessions.create!(user_agent: "Rails Test", ip_address: "127.0.0.1")
    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    jar.signed[:session_id] = session.id
    cookies[:session_id] = jar[:session_id]
  end

end

class ActionDispatch::IntegrationTest
  include AuthenticationTestHelper
end
