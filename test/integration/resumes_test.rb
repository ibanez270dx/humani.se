require "test_helper"

class ResumesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = Admin.create!(email: Admin::OWNER_EMAIL, role: "owner")
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "public resume is inline with fresh validators and HEAD has no body" do
    original = publish("resume")
    get "/resume"
    assert_response :success
    assert_equal original.pdf_data, response.body.b
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline;/, response.headers["Content-Disposition"])
    assert_includes response.headers["Content-Disposition"], "jeff-miller-resume.pdf"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    %w[public no-cache].each{ |directive| assert_includes response.headers["Cache-Control"], directive }
    first_etag = response.headers.fetch("ETag")
    get "/resume", headers: { "If-None-Match" => first_etag }
    assert_response :not_modified
    assert_empty response.body
    head "/resume"
    assert_response :success
    assert_empty response.body
    assert_equal first_etag, response.headers["ETag"]
    replacement = publish("replacement")
    get "/resume", headers: { "If-None-Match" => first_etag }
    assert_response :success
    assert_equal replacement.pdf_data, response.body.b
    assert_not_equal first_etag, response.headers["ETag"]
    get "/resume", headers: { "Range" => "bytes=0-99" }
    assert_response :success
    assert_equal replacement.pdf_data, response.body.b
    assert_nil response.headers["Accept-Ranges"]
  end

  test "legacy URL redirects and missing resume returns a controlled 404" do
    get "/resume"
    assert_response :not_found
    assert_not_equal "application/pdf", response.media_type
    assert_not File.exist?(Rails.public_path.join("jeff-miller-resume.pdf"))
    publish("resume")
    get "/jeff-miller-resume.pdf"
    assert_redirected_to "/resume"
    assert_includes response.headers["Cache-Control"], "no-cache"
    follow_redirect!
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "only the active owner can manage uploads on the admin host" do
    publish("resume")
    patch "/resume", params: upload_params
    assert_response :not_found
    host! "admin.humani.se"
    get "/resume"
    assert_redirected_to admin_sign_in_path
    patch "/resume", params: upload_params
    assert_redirected_to admin_sign_in_path
    admin = Admin.create!(email: "friend@example.com")
    login(admin)
    get "/resume"
    assert_response :forbidden
    patch "/resume", params: upload_params
    assert_response :forbidden
    login(@owner)
    @owner.admin_sessions.update_all(expires_at: 1.second.ago)
    patch "/resume", params: upload_params
    assert_redirected_to admin_sign_in_path
    login(admin)
    admin.update!(revoked_at: Time.current)
    patch "/resume", params: upload_params
    assert_redirected_to admin_sign_in_path
    assert_equal File.binread(file_fixture("resume.pdf")), Resume.current.pdf_data
  end

  test "owner upload publishes exact bytes and exposes a canonical public preview link" do
    host! "admin.humani.se"
    login(@owner)
    get "/resume"
    assert_response :success
    assert_select "a[href='https://www.humani.se/resume'][target='_blank'][rel='noopener']" do |links|
      assert_equal "#{links.first.text} (opens in a new tab)", links.first["aria-label"]
    end
    assert_select "form[enctype='multipart/form-data'] input[type='file'][accept='application/pdf,.pdf']"
    assert_select "script", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]
    patch "/resume", params: upload_params
    assert_redirected_to admin_resume_path
    assert_not_empty request.env.fetch("rack.tempfiles")
    assert request.env.fetch("rack.tempfiles").all?(&:closed?)
    follow_redirect!
    assert_select "p[role='status']", "Resume published."
    assert_select "dd", @owner.email
    assert_equal @owner, Resume.current.uploaded_by
    host! "www.humani.se"
    get "/resume"
    assert_response :success
    assert_equal File.binread(file_fixture("replacement.pdf")), response.body.b
  end

  test "invalid and malformed uploads preserve the published resume" do
    original = publish("resume").attributes
    host! "admin.humani.se"
    login(@owner)
    patch "/resume", params: { resume: { pdf: fixture_file_upload("malformed.pdf", "application/pdf") } }
    assert_response :unprocessable_entity
    assert_select "p[role='alert']"
    assert_not_empty request.env.fetch("rack.tempfiles")
    assert request.env.fetch("rack.tempfiles").all?(&:closed?)
    assert_equal original, Resume.current.attributes
    [nil, "bad", { pdf: "bad" }, { pdf: ["bad"] }, {}].each do |input|
      patch "/resume", params: { resume: input }
      assert_response :bad_request
      assert_equal original, Resume.current.attributes
    end
  end

  test "PDF content is validated independently of the client filename and MIME type" do
    host! "admin.humani.se"
    login(@owner)
    patch "/resume", params: { resume: { pdf: fixture_file_upload("replacement.pdf", "text/plain") } }
    assert_response :see_other
    host! "www.humani.se"
    get "/resume"
    assert_equal "application/pdf", response.media_type
  end

  test "owner upload requires a Rails CSRF token" do
    host! "admin.humani.se"
    login(@owner)
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "Resume.count" do
      patch "/resume", params: upload_params
      assert_response :unprocessable_entity
    end
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  private

  def publish(name)
    File.open(file_fixture("#{name}.pdf"), "rb"){ |file| Resume.publish!(io: file, filename: "#{name}.pdf", uploaded_by: @owner) }
  end

  def upload_params
    { resume: { pdf: fixture_file_upload("replacement.pdf", "application/pdf") } }
  end

  def login(admin)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "google-#{admin.id}",
      info: { email: admin.email, name: "Jeff" },
      extra: { raw_info: { email_verified: true } }
    )
    get "/auth/google_oauth2/callback"
  end
end
