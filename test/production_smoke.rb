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

  def test_allowed_hosts_and_health
    %w[humani.se www.humani.se humanise.herokuapp.com].each do |host|
      @session.host! host
      @session.get "/up"
      assert_equal 200, @session.response.status, host
    end
  end

  def test_unknown_hosts_are_rejected
    @session.host! "attacker.example"
    @session.get "/"
    assert_equal 403, @session.response.status
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
