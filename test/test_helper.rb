ENV["RAILS_ENV"] ||= "test"
ENV["NISA_PASSWORD"] ||= "test-nisa-password-2026"
require_relative "../config/environment"
require "rails/test_help"

module NisaLoginTestHelper
  def sign_in_as_nisa
    post login_url, params: { username: "Nisa", password: ENV.fetch("NISA_PASSWORD") }
    assert_redirected_to root_url
  end
end

ActionDispatch::IntegrationTest.include(NisaLoginTestHelper)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
