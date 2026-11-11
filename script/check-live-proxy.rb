require "json"
require "net/http"
require "securerandom"
require "uri"

# Run explicitly after deploying the expected commit. This is not a local smoke
# test and must not run automatically against production for every pull request.
class LiveProxyCheck
  class Failure < StandardError; end

  CHECKS = %w[ip_spoofing_check_enabled x_forwarded_for_valid remote_ip_matches_forwarded_for
    x_forwarded_proto_https x_forwarded_port_https request_https].freeze

  def initialize(origin:, expected_sha:, http_factory: Net::HTTP.method(:new))
    @origin = URI.parse(origin)
    unless @origin.is_a?(URI::HTTPS) && @origin.host && @origin.port == 443 &&
        @origin.userinfo.nil? && ["", "/"].include?(@origin.path) && @origin.query.nil? && @origin.fragment.nil?
      raise Failure, "Use an HTTPS origin with no credentials, path, query or fragment"
    end
    raise Failure, "Expected SHA must be the full 40-character deployed commit" unless /\A[0-9a-f]{40}\z/.match?(expected_sha)

    @expected_sha = expected_sha
    @http_factory = http_factory
  rescue URI::InvalidURIError
    raise Failure, "Invalid HTTPS origin"
  end

  def run
    nonce = SecureRandom.hex(16)
    uri = @origin.dup
    uri.path = "/status/proxy"
    # A unique URL plus an echoed nonce prevents a cached report from passing.
    uri.query = URI.encode_www_form(probe: nonce)
    response, body = fetch(uri, nonce)
    raise Failure, "Proxy probe returned HTTP #{response.code}; no redirects are followed" unless response.code == "200"
    raise Failure, "Proxy probe did not return JSON" unless response["Content-Type"].to_s.split(";").first == "application/json"
    raise Failure, "Proxy probe must be marked no-store" unless response["Cache-Control"].to_s.split(",").map(&:strip).include?("no-store")

    payload = JSON.parse(body)
    raise Failure, "Unexpected proxy probe schema" unless payload.is_a?(Hash) && payload["schema"] == 1
    raise Failure, "Proxy probe returned a stale or unrelated response" unless payload["nonce"] == nonce
    raise Failure, "The expected commit is not deployed" unless payload["sha"] == @expected_sha
    raise Failure, "The target is not running in production mode" unless payload["environment"] == "production"
    unless payload["actionpack_version"] == "8.1.4.1"
      raise Failure, "The target is not running Action Pack 8.1.4.1"
    end
    checks = payload["checks"]
    failed = CHECKS.reject{ |key| checks.is_a?(Hash) && checks[key] == true }
    raise Failure, "Proxy checks failed: #{failed.join(', ')}" unless failed.empty?
    unless [true, false].include?(payload["forwarded_present"])
      raise Failure, "Missing Forwarded header presence report"
    end

    "PASS: live proxy headers checked at #{@origin.host} for #{@expected_sha} " \
      "(Forwarded present: #{payload['forwarded_present']})"
  rescue JSON::ParserError
    raise Failure, "Proxy probe returned invalid JSON"
  rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    raise Failure, "Proxy probe connection failed; verify DNS, TLS and connectivity"
  end

  private

  def fetch(uri, nonce)
    # Do not send cookies, authorization, or synthetic forwarding headers. Do not
    # use an environment-configured HTTP proxy that could alter the observation.
    http = @http_factory.call(uri.host, uri.port, nil)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 5
    http.read_timeout = 10
    http.write_timeout = 5
    http.max_retries = 0
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json"
    request["Cache-Control"] = "no-cache"
    request["X-Humanise-Proxy-Nonce"] = nonce
    body = +""
    response = http.request(request) do |result|
      result.read_body do |chunk|
        raise Failure, "Proxy probe response is too large" if body.bytesize + chunk.bytesize > 16_384
        body << chunk
      end
    end
    [response, body]
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby script/check-live-proxy.rb HTTPS_ORIGIN EXPECTED_DEPLOYED_SHA" unless ARGV.length == 2
  begin
    puts LiveProxyCheck.new(origin: ARGV[0], expected_sha: ARGV[1]).run
  rescue LiveProxyCheck::Failure => error
    warn "FAIL: #{error.message}"
    exit 1
  end
end
