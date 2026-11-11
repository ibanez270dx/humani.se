require "test_helper"

class ProxyChecksTest < ActionDispatch::IntegrationTest
  setup do
    host! "www.humani.se"
    https!
    @headers = {
      "X-Humanise-Proxy-Nonce" => "a" * 32,
      "X-Forwarded-For" => "203.0.113.9, 10.0.0.2",
      "X-Forwarded-Proto" => "https",
      "X-Forwarded-Port" => "443"
    }
  end

  test "reports received forwarding checks without exposing addresses or headers" do
    get "/status/proxy", headers: @headers
    assert_response :success
    payload = response.parsed_body
    assert_equal %w[actionpack_version checks environment forwarded_present nonce schema sha], payload.keys.sort
    assert_equal 1, payload.fetch("schema")
    assert_equal "a" * 32, payload.fetch("nonce")
    assert_equal "test", payload.fetch("sha")
    assert_equal ActionPack::VERSION::STRING, payload.fetch("actionpack_version")
    assert_equal false, payload.fetch("forwarded_present")
    assert payload.fetch("checks").values.all?{ |value| value == true }
    refute_includes response.body, "203.0.113.9"
    refute_includes response.body, "10.0.0.2"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "requires a bounded hexadecimal nonce and never reflects invalid input" do
    [nil, "not-a-nonce", "a" * 33].each do |nonce|
      get "/status/proxy", headers: @headers.merge("X-Humanise-Proxy-Nonce" => nonce)
      assert_response :bad_request
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "fails instead of reporting success without forwarding evidence" do
    %w[X-Forwarded-For X-Forwarded-Proto X-Forwarded-Port].each do |header|
      get "/status/proxy", headers: @headers.except(header)
      assert_response :service_unavailable
      assert_includes response.parsed_body.fetch("checks").values, false
    end
  end

  test "reports Forwarded presence when the two families agree" do
    get "/status/proxy", headers: @headers.merge("Forwarded" => "for=203.0.113.9;proto=https")
    assert_response :success
    assert_equal true, response.parsed_body.fetch("forwarded_present")
    refute_includes response.body, "203.0.113.9"
  end

  test "rejects invalid forwarding address lists and HTTP metadata" do
    ["unknown", "203.0.113.9/32", "203.0.113.9,", "203.0.113.9, invalid"].each do |value|
      get "/status/proxy", headers: @headers.merge("X-Forwarded-For" => value)
      assert_response :service_unavailable
      assert_equal false, response.parsed_body.fetch("checks").fetch("x_forwarded_for_valid")
    end
    get "/status/proxy", headers: @headers.merge("X-Forwarded-Proto" => "http", "X-Forwarded-Port" => "80")
    assert_response :service_unavailable
  end

  test "is read-only and does not change the existing status schema" do
    post "/status/proxy", headers: @headers
    assert_response :not_found
    get "/status"
    assert_equal %w[deployed_at environment sha started_at version], response.parsed_body.keys.sort
  end
end
