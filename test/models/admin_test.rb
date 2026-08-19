require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "valid with email and password" do
    admin = Admin.new(email: "admin@example.com", password: "s3cret-password")
    assert admin.valid?
  end

  test "authenticates with the correct password only" do
    admin = Admin.create!(email: "admin2@example.com", password: "correct-password")

    assert admin.authenticate("correct-password")
    assert_not admin.authenticate("wrong-password")
  end

  test "rejects duplicate email" do
    Admin.create!(email: "dup@example.com", password: "password123")
    dup = Admin.new(email: "dup@example.com", password: "password456")

    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "rejects malformed email" do
    admin = Admin.new(email: "not-an-email", password: "password123")
    assert_not admin.valid?
    assert_includes admin.errors[:email], "is invalid"
  end
end
