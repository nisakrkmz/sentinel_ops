ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module OperatorLoginTestHelper
  TEST_PASSWORD = "test-operator-password-2026".freeze

  def sign_in_as_nisa
    user = User.find_by(email: "nisa@test.local") ||
      User.create!(name: "Nisa", email: "nisa@test.local", password: TEST_PASSWORD)
    post login_url, params: { email: user.email, password: TEST_PASSWORD }
    assert_redirected_to root_url
    user
  end
end

ActionDispatch::IntegrationTest.include(OperatorLoginTestHelper)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
