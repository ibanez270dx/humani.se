require "test_helper"

class AdminModelTest < ActiveSupport::TestCase
  test "audit events distinguish the affected admin from the actor and prevent deleting either" do
    owner = Admin.create!(email: "jeff@humani.se", role: "owner")
    admin = Admin.create!(email: "friend@example.com")
    event = AdminAccessEvent.create!(actor: owner, admin: admin, action: "invited")
    login = admin.admin_sessions.create!(token_digest: AdminSession.digest("token"), expires_at: 1.day.from_now)

    assert_equal [event], admin.admin_access_events.to_a
    assert_equal [event], owner.performed_admin_access_events.to_a
    assert_empty owner.admin_access_events
    assert_empty admin.performed_admin_access_events
    assert_raises(ActiveRecord::DeleteRestrictionError){ admin.destroy! }
    assert_raises(ActiveRecord::DeleteRestrictionError){ owner.destroy! }
    assert AdminAccessEvent.exists?(event.id)
    assert AdminSession.exists?(login.id)
  end

  test "ownership is fixed and cannot be revoked or reassigned" do
    owner = Admin.create!(email: "jeff@humani.se", role: "owner")
    assert_not owner.update(role: "admin")
    owner.reload
    assert_not owner.update(revoked_at: Time.current)
    assert_not Admin.new(email: "friend@example.com", role: "owner").valid?
    assert_not Admin.new(email: "jeff@humani.se", role: "admin").valid?
  end

  test "email and identity are unique and email cannot transfer an account" do
    admin = Admin.create!(email: " FRIEND@example.com ", google_uid: "google-123")
    assert_equal "friend@example.com", admin.email
    assert_not Admin.new(email: "FRIEND@example.com").valid?
    assert_not Admin.new(email: "other@example.com", google_uid: "google-123").valid?
    assert_not admin.update(email: "other@example.com")
  end
end
