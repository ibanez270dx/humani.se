require "test_helper"

class ProxyHeaderCheckTest < ActiveSupport::TestCase
  test "forces Rails to reject conflicting Forwarded and X-Forwarded-For" do
    request = proxy_request("HTTP_FORWARDED" => "for=198.51.100.8")
    assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError){ ProxyHeaderCheck.call(request) }
  end

  test "forces Rails to reject conflicting Client-Ip" do
    request = proxy_request("HTTP_CLIENT_IP" => "198.51.100.8")
    assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError){ ProxyHeaderCheck.call(request) }
  end

  test "allows matching dual-family IPv6 forwarding chains" do
    request = proxy_request(
      "HTTP_FORWARDED" => 'for="[2001:db8::9]";proto=https',
      "HTTP_X_FORWARDED_FOR" => "2001:db8::9, 10.0.0.2"
    )
    assert ProxyHeaderCheck.call(request).values.all?{ |value| value == true }
  end

  test "never passes with the spoofing check disabled" do
    config = Rails.application.config.action_dispatch
    previous = config.ip_spoofing_check
    config.ip_spoofing_check = false
    assert_equal false, ProxyHeaderCheck.call(proxy_request).fetch(:ip_spoofing_check_enabled)
  ensure
    config.ip_spoofing_check = previous
  end

  private

  def proxy_request(headers = {})
    observed = nil
    app = ->(env){ observed = ActionDispatch::Request.new(env); [200, {}, []] }
    env = Rack::MockRequest.env_for("https://www.humani.se/status/proxy", {
      "REMOTE_ADDR" => "10.0.0.3",
      "HTTP_X_FORWARDED_FOR" => "203.0.113.9, 10.0.0.2",
      "HTTP_X_FORWARDED_PROTO" => "https",
      "HTTP_X_FORWARDED_PORT" => "443"
    }.merge(headers))
    ActionDispatch::RemoteIp.new(app).call(env)
    observed
  end
end
