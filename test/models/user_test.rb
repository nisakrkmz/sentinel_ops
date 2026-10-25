require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "passwords are stored as salted PBKDF2 digests" do
    first = User.create!(name: "A", email: "a@example.com", password: "same-password-1")
    second = User.create!(name: "B", email: "b@example.com", password: "same-password-1")

    assert_match(/\Apbkdf2_sha256\$\d+\$\h{32}\$\h{64}\z/, first.password_digest)
    assert_not_equal first.password_digest, second.password_digest
    assert_equal first, User.authenticate("A@Example.com", "same-password-1")
    assert_nil User.authenticate("a@example.com", "wrong")
    assert_nil User.authenticate("missing@example.com", "same-password-1")
  end
end
