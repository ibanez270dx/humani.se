# Run after assets:precompile with RAILS_ENV=production via bin/rails runner.
raise "Run in production" unless Rails.env.production?

require "minitest/autorun"

class ProductionSmokeTest < Minitest::Test
  def setup
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    @session.host! "www.humani.se"
    @session.https!
  end

  def test_page_policy_and_compiled_assets
    @session.get "/"
    assert_equal 200, @session.response.status
    policy = @session.response.headers.fetch("Content-Security-Policy")
    ["default-src 'self'", "script-src 'none'", "style-src 'self'", "object-src 'none'", "frame-ancestors 'none'"].each do |directive|
      assert_includes policy, directive
    end

    page = Nokogiri::HTML(@session.response.body)
    urls = page.css("link[rel=stylesheet]").map{ |node| node["href"] }
    image = page.at_css(".night-sky img")
    urls << image["src"]
    urls.concat(image["srcset"].split(",").map{ |candidate| candidate.split.first })
    urls.concat(%w[/social-preview.jpg /jeff-miller-resume.pdf /manifest.json])
    urls.uniq.each do |url|
      @session.get url
      assert_equal 200, @session.response.status, url
    end
  end

  def test_status_stays_public_and_startup_timestamp_is_stable
    @session.get "/status"
    assert_equal 200, @session.response.status
    payload = @session.response.parsed_body
    assert_equal %w[deployed_at environment sha started_at version], payload.keys.sort
    @session.get "/status"
    assert_equal payload.fetch("started_at"), @session.response.parsed_body.fetch("started_at")
  end

  def test_error_responses_and_their_static_assets
    @session.get "/a-page-that-does-not-exist", headers: { "Accept" => "text/html" }
    assert_equal 404, @session.response.status
    assert_includes @session.response.body, "A little off course"

    old_browser = "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko"
    @session.get "/", headers: { "User-Agent" => old_browser }
    assert_equal 406, @session.response.status
    assert_includes @session.response.body, "Time for an update"
    assert_includes @session.response.headers.fetch("Content-Security-Policy"), "style-src 'self'"

    # These assets must remain available even to unsupported browsers.
    %w[/error.css /error-background.webp].each do |url|
      @session.get url, headers: { "User-Agent" => old_browser }
      assert_equal 200, @session.response.status, url
    end
  end

  def test_public_exception_handler_preserves_error_statuses
    handler = ActionDispatch::PublicExceptions.new(Rails.public_path)
    { 422 => "Let’s try that again", 500 => "A brief interruption" }.each do |status, heading|
      env = Rack::MockRequest.env_for("/#{status}", "HTTP_ACCEPT" => "text/html")
      response_status, _headers, body = handler.call(env)
      assert_equal status, response_status
      assert_includes body.join.force_encoding(Encoding::UTF_8), heading
    end
  end

  def test_allowed_hosts_and_health
    %w[humani.se www.humani.se admin.humani.se humanise.herokuapp.com].each do |host|
      @session.host! host
      @session.get "/up"
      assert_equal 200, @session.response.status, host
    end
  end

  def test_admin_routing_policy_and_local_assets
    @session.host! "admin.humani.se"
    @session.get "/"
    assert_equal 302, @session.response.status
    assert_equal "https://admin.humani.se/sign-in", @session.response.location
    @session.get "/sign-in"
    assert_equal 200, @session.response.status
    policy = @session.response.headers.fetch("Content-Security-Policy")
    ["form-action 'self' https://accounts.google.com", "script-src 'none'", "frame-ancestors 'none'"].each do |directive|
      assert_includes policy, directive
    end
    assert_equal "no-store", @session.response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", @session.response.headers["X-Robots-Tag"]
    cookie = @session.response.headers["set-cookie"].to_s
    assert_includes cookie, "__Host-humanise_session="
    assert_includes cookie, "secure"
    assert_includes cookie, "httponly"
    assert_includes cookie, "samesite=lax"
    refute_match(/domain=/i, cookie)
    page = Nokogiri::HTML(@session.response.body)
    assert_equal 0, page.css("script").size
    page.css("link[rel=stylesheet]").each do |node|
      @session.get node["href"]
      assert_equal 200, @session.response.status
    end
    @session.https! false
    @session.get "/sign-in"
    assert_equal "https://admin.humani.se/sign-in", @session.response.location
  end

  def test_admin_routes_are_absent_on_public_hosts
    %w[/sign-in /admins /auth/google_oauth2 /auth/google_oauth2/callback].each do |path|
      @session.get path
      assert_equal 404, @session.response.status, path
    end
    @session.post "/auth/google_oauth2"
    assert_equal 404, @session.response.status
    @session.get "/"
    assert_includes @session.response.headers.fetch("Content-Security-Policy"), "form-action 'none'"
  end

  def test_unknown_hosts_are_rejected
    %w[attacker.example lvh.me admin.lvh.me].each do |host|
      @session.host! host
      @session.get "/"
      assert_equal 403, @session.response.status
    end
  end

  def test_untrusted_forwarded_host_is_rejected
    @session.get "/", headers: { "X-Forwarded-Host" => "attacker.example" }
    assert_equal 403, @session.response.status
  end

  def test_http_redirects_to_https
    @session.https! false
    @session.get "/"
    assert_equal 301, @session.response.status
    assert_equal "https://www.humani.se/", @session.response.location
  end

  def test_heroku_forwarded_https_does_not_redirect
    @session.https! false
    @session.get "/", headers: { "X-Forwarded-Proto" => "https", "X-Forwarded-Port" => "443" }
    assert_equal 200, @session.response.status
  end
end
