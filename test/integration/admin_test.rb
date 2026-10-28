require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.humani.se"
    @owner = Admin.create!(email: "jeff@humani.se", role: "owner")
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    ActionController::Base.allow_forgery_protection = false
  end

  test "admin routes and middleware are restricted to exact admin hosts" do
    %w[www.humani.se humani.se lvh.me localhost:3001 attacker.example admin.humani.se.attacker.example admin.lvh.me.attacker.example].each do |hostname|
      host! hostname
      %w[/sign-in /admins /auth/google_oauth2/callback /auth/google_oauth2].each do |path|
        get path
        assert_response :not_found
      end
      post "/auth/google_oauth2"
      assert_response :not_found
    end
    host! "admin.lvh.me:3000"
    get "/sign-in"
    assert_response :success
  end

  test "one local server serves public and admin hosts separately" do
    host! "lvh.me:3000"
    get "/"
    assert_response :success
    assert_select "h1", "Hi. I’m Jeff."
    host! "admin.lvh.me:3000"
    get "/"
    assert_redirected_to admin_sign_in_path
    get admin_sign_in_path
    assert_response :success
    assert_select "h1", "Welcome back."
  end

  test "anonymous users must sign in and sign-in is private and script free" do
    get "/"
    assert_redirected_to admin_sign_in_path
    get "/sign-in"
    assert_response :success
    assert_select "h1", "Welcome back."
    assert_select "form[action='/auth/google_oauth2'][method='post']"
    assert_select "script", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "approved Google account binds identity and starts a seven day session" do
    sign_in(@owner.email)
    assert_redirected_to admin_root_path
    assert_equal "google-123", @owner.reload.google_uid
    assert_equal "Jeff", @owner.name
    login = @owner.admin_sessions.sole
    assert_in_delta 7.days.from_now, login.expires_at, 5
    assert_equal AdminSession.digest(cookies[AdminSession::COOKIE_NAME]), login.token_digest
    assert_not_equal cookies[AdminSession::COOKIE_NAME], login.token_digest
    follow_redirect!
    assert_select "h1", "Dashboard"
    assert_select "a[href='/admins']"
  end

  test "unapproved unverified and mismatched identities cannot sign in" do
    sign_in("stranger@example.com")
    assert_redirected_to admin_sign_in_path
    assert_equal 0, AdminSession.count
    sign_in(@owner.email, verified: false)
    assert_equal 0, AdminSession.count
    @owner.update!(google_uid: "original")
    sign_in(@owner.email, uid: "replacement")
    assert_equal 0, AdminSession.count
    assert_equal "original", @owner.reload.google_uid
  end

  test "bound identity survives Google email changes without granting access to replacements" do
    sign_in(@owner.email)
    delete admin_sign_out_path
    sign_in("changed@example.com")
    assert_redirected_to admin_root_path
    assert_equal @owner.id, AdminSession.sole.admin_id
    delete admin_sign_out_path
    sign_in(@owner.email, uid: "replacement")
    assert_redirected_to admin_sign_in_path
    assert_equal 0, AdminSession.count
  end

  test "owner can invite revoke and restore with an audit trail" do
    sign_in(@owner.email)
    post admin_admins_path, params: { admin: { email: "  Friend@Example.com  ", role: "owner" } }
    friend = Admin.find_by!(email: "friend@example.com")
    assert_equal "admin", friend.role
    assert_equal "Invited", friend.access_status
    assert_equal @owner, AdminAccessEvent.sole.actor
    assert_equal "invited", AdminAccessEvent.sole.action
    friend.admin_sessions.create!(token_digest: AdminSession.digest("friend-token"), expires_at: 1.day.from_now)
    patch admin_admin_path(friend), params: { access: "revoke" }
    assert_not friend.reload.active?
    assert_equal 0, friend.admin_sessions.count
    patch admin_admin_path(friend), params: { access: "restore" }
    assert friend.reload.active?
    assert_equal %w[invited revoked restored], AdminAccessEvent.order(:id).pluck(:action)
    get admin_admins_path
    assert_response :success
    assert_select "th", "friend@example.com"
  end

  test "invalid and duplicate invitations are rendered without granting access" do
    sign_in(@owner.email)
    assert_no_difference "Admin.count" do
      post admin_admins_path, params: { admin: { email: "not-an-email" } }
      assert_response :unprocessable_entity
      post admin_admins_path, params: { admin: { email: "JEFF@HUMANI.SE" } }
      assert_response :unprocessable_entity
    end
    assert_equal 0, AdminAccessEvent.count
  end

  test "admins can use dashboard but cannot manage access" do
    friend = Admin.create!(email: "friend@example.com")
    sign_in(friend.email)
    get admin_root_path
    assert_response :success
    assert_select "a[href='/admins']", count: 0
    get admin_admins_path
    assert_response :forbidden
    post admin_admins_path, params: { admin: { email: "other@example.com" } }
    assert_response :forbidden
    patch admin_admin_path(@owner), params: { access: "revoke" }
    assert_response :forbidden
    assert @owner.reload.active?
  end

  test "owner cannot revoke owner account" do
    sign_in(@owner.email)
    patch admin_admin_path(@owner), params: { access: "revoke" }
    assert_response :forbidden
    assert @owner.reload.active?
  end

  test "revocation denies existing sessions and future sign-ins" do
    friend = Admin.create!(email: "friend@example.com")
    sign_in(friend.email)
    friend.update!(revoked_at: Time.current)
    get admin_root_path
    assert_redirected_to admin_sign_in_path
    sign_in(friend.email)
    assert_redirected_to admin_sign_in_path
  end

  test "expired sessions and signed out sessions cannot be reused" do
    sign_in(@owner.email)
    @owner.admin_sessions.update_all(expires_at: 1.second.ago)
    get admin_root_path
    assert_redirected_to admin_sign_in_path
    sign_in(@owner.email)
    token = cookies[AdminSession::COOKIE_NAME]
    delete admin_sign_out_path
    assert_redirected_to admin_sign_in_path
    assert_not AdminSession.exists?(token_digest: AdminSession.digest(token))
    cookies[AdminSession::COOKIE_NAME] = token
    get admin_root_path
    assert_redirected_to admin_sign_in_path
  end

  test "Google authentication failures render a safe retry page" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    get "/auth/google_oauth2/callback"
    assert_redirected_to "/sign-in?error=authentication"
    follow_redirect!
    assert_select "[role='alert']", "Google sign-in could not be completed. Please try again."
  end

  test "Google request requires POST with a valid Rails CSRF token" do
    OmniAuth.config.test_mode = false
    ActionController::Base.allow_forgery_protection = true
    get "/auth/google_oauth2"
    assert_response :not_found
    post "/auth/google_oauth2"
    assert_redirected_to "/sign-in?error=authentication"
    get admin_sign_in_path
    token = css_select("input[name=authenticity_token]").first["value"]
    post "/auth/google_oauth2", params: { authenticity_token: token, state: "attacker", scope: "https://www.googleapis.com/auth/drive", redirect_uri: "https://attacker.example" }
    assert_response :redirect
    uri = URI(response.location)
    assert_equal "accounts.google.com", uri.host
    query = URI.decode_www_form(uri.query).to_h
    assert_equal "http://admin.lvh.me:3000/auth/google_oauth2/callback", query["redirect_uri"]
    assert_equal "email openid profile", query["scope"].split.sort.join(" ")
    assert_not_equal "attacker", query["state"]
    assert_equal "S256", query["code_challenge_method"]
    assert_equal "online", query["access_type"]
  end

  test "Google callback requires matching OAuth state" do
    OmniAuth.config.test_mode = false
    get "/auth/google_oauth2/callback", params: { code: "not-a-code", state: "attacker" }
    assert_redirected_to "/sign-in?error=authentication"
    assert_equal 0, AdminSession.count
  end

  test "admin mutations require Rails CSRF tokens" do
    sign_in(@owner.email)
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "Admin.count" do
      post admin_admins_path, params: { admin: { email: "friend@example.com" } }
      assert_response :unprocessable_entity
    end
  end

  private

  def sign_in(email, uid: "google-123", verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid,
      info: { email: email, name: "Jeff" },
      extra: { raw_info: { email_verified: verified } }
    )
    get "/auth/google_oauth2/callback"
  end
end
