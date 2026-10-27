require "test_helper"

class AdministratorTest < ActiveSupport::TestCase
  test "ownership is fixed and cannot be revoked or reassigned" do
    owner = Administrator.create!(email: "jeff@humani.se", role: "owner")
    assert_not owner.update(role: "admin")
    owner.reload
    assert_not owner.update(revoked_at: Time.current)
    assert_not Administrator.new(email: "friend@example.com", role: "owner").valid?
    assert_not Administrator.new(email: "jeff@humani.se", role: "admin").valid?
  end

  test "email and identity are unique and email cannot transfer an account" do
    administrator = Administrator.create!(email: " FRIEND@example.com ", google_uid: "google-123")
    assert_equal "friend@example.com", administrator.email
    assert_not Administrator.new(email: "FRIEND@example.com").valid?
    assert_not Administrator.new(email: "other@example.com", google_uid: "google-123").valid?
    assert_not administrator.update(email: "other@example.com")
  end
end
