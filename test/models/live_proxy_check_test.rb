require "test_helper"
require "minitest/mock"
require_relative "../../script/check-live-proxy"

class LiveProxyCheckTest < ActiveSupport::TestCase
  SHA = "a" * 40

  test "checks a nonce-bound production response for the exact deployed commit" do
    assert_includes probe.run, "PASS: live proxy headers checked at www.humani.se"
  end

  test "fails closed for stale responses and a different deployed release" do
    [
      { "nonce" => "b" * 32 }, { "sha" => "b" * 40 }, { "sha" => nil },
      { "environment" => "test" }, { "actionpack_version" => "8.1.4" },
      { "schema" => 2 }, { "forwarded_present" => nil }
    ].each do |replacement|
      assert_raises(LiveProxyCheck::Failure){ probe(replacement).run }
    end
  end

  test "requires each known check to be boolean true" do
    LiveProxyCheck::CHECKS.each do |key|
      [false, nil, "true"].each do |value|
        checks = LiveProxyCheck::CHECKS.to_h{ |name| [name, true] }.merge(key => value)
        assert_raises(LiveProxyCheck::Failure){ probe({ "checks" => checks }).run }
      end
    end
    [nil, [], {}].each do |checks|
      assert_raises(LiveProxyCheck::Failure){ probe({ "checks" => checks }).run }
    end
  end

  test "rejects redirects error statuses and non-JSON or cacheable reports" do
    %w[301 302 403 404 500 503].each do |status|
      assert_raises(LiveProxyCheck::Failure){ probe({}, code: status).run }
    end
    assert_raises(LiveProxyCheck::Failure){ probe({}, content_type: "text/html").run }
    assert_raises(LiveProxyCheck::Failure){ probe({}, cache_control: "public, max-age=300").run }
  end

  test "rejects unsafe origins and incomplete commit identifiers before networking" do
    [
      "http://www.humani.se", "https://user:pass@www.humani.se", "https://www.humani.se/path",
      "https://www.humani.se?query=1", "https://www.humani.se#fragment", "https://www.humani.se:8443"
    ].each do |origin|
      assert_raises(LiveProxyCheck::Failure){ LiveProxyCheck.new(origin: origin, expected_sha: SHA) }
    end
    ["", "abc1234", "a" * 41, "g" * 40].each do |sha|
      assert_raises(LiveProxyCheck::Failure){ LiveProxyCheck.new(origin: "https://www.humani.se", expected_sha: sha) }
    end
  end

  test "rejects malformed JSON and non-object responses" do
    ["not JSON", "null", "[]", "true"].each do |body|
      checker = probe
      checker.define_singleton_method(:fetch) do |_uri, _nonce|
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response["Content-Type"] = "application/json"
        response["Cache-Control"] = "no-store"
        [response, body]
      end
      assert_raises(LiveProxyCheck::Failure){ checker.run }
    end
  end

  test "transport sends only an ordinary bounded verified HTTPS request" do
    http = TransportDouble.new(["{}"])
    Net::HTTP.stub(:new, ->(host, port, proxy){
      assert_equal "www.humani.se", host
      assert_equal 443, port
      assert_nil proxy
      http
    }) do
      checker = LiveProxyCheck.new(origin: "https://www.humani.se", expected_sha: SHA)
      checker.send(:fetch, URI("https://www.humani.se/status/proxy"), "a" * 32)
    end
    assert_equal true, http.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
    assert_equal [5, 10, 5, 0], [http.open_timeout, http.read_timeout, http.write_timeout, http.max_retries]
    assert_equal "GET", http.sent_request.method
    assert_equal "a" * 32, http.sent_request["X-Humanise-Proxy-Nonce"]
    %w[Authorization Cookie Forwarded X-Forwarded-For X-Forwarded-Proto Client-Ip].each do |header|
      assert_nil http.sent_request[header]
    end
  end

  test "transport rejects an oversized response and reports timeouts without server details" do
    checker = LiveProxyCheck.new(origin: "https://www.humani.se", expected_sha: SHA)
    Net::HTTP.stub(:new, TransportDouble.new(["a" * 16_384, "b"])) do
      assert_raises(LiveProxyCheck::Failure){ checker.run }
    end
    checker.define_singleton_method(:fetch){ |_uri, _nonce| raise Net::ReadTimeout, "private details" }
    error = assert_raises(LiveProxyCheck::Failure){ checker.run }
    refute_includes error.message, "private details"
  end

  class TransportDouble
    attr_accessor :use_ssl, :verify_mode, :open_timeout, :read_timeout, :write_timeout, :max_retries
    attr_reader :sent_request

    def initialize(chunks)
      @response = Net::HTTPOK.new("1.1", "200", "OK")
      @response.define_singleton_method(:read_body){ |&block| chunks.each(&block) }
    end

    def request(request)
      @sent_request = request
      yield @response
      @response
    end
  end

  private

  def probe(replacement = {}, code: "200", content_type: "application/json; charset=utf-8", cache_control: "no-store")
    checker = LiveProxyCheck.new(origin: "https://www.humani.se", expected_sha: SHA)
    checker.define_singleton_method(:fetch) do |uri, nonce|
      raise "Unexpected request target" unless uri.path == "/status/proxy" && uri.query == "probe=#{nonce}"
      response = Net::HTTPResponse.new("1.1", code, "Test")
      response["Content-Type"] = content_type
      response["Cache-Control"] = cache_control
      payload = {
        "schema" => 1, "nonce" => nonce, "sha" => SHA, "environment" => "production",
        "actionpack_version" => "8.1.4.1", "forwarded_present" => false,
        "checks" => LiveProxyCheck::CHECKS.to_h{ |key| [key, true] }
      }.merge(replacement)
      [response, JSON.generate(payload)]
    end
    checker
  end
end
