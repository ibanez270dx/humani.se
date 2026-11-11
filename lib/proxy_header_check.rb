require "ipaddr"

# A deliberately value-free report: never serialize request headers or addresses.
class ProxyHeaderCheck
  def self.call(request)
    forwarded_ips = request.get_header("HTTP_X_FORWARDED_FOR").to_s.split(",", -1).map(&:strip)
    valid_ips = forwarded_ips.any? && forwarded_ips.all? do |ip|
      !ip.include?("/") && IPAddr.new(ip)
    rescue IPAddr::InvalidAddressError
      false
    end

    # RemoteIp is lazy. Explicitly evaluate it to exercise Rails' conflict checks
    # between Forwarded, X-Forwarded-For and Client-Ip on this actual request.
    remote_ip = request.remote_ip

    {
      ip_spoofing_check_enabled: Rails.application.config.action_dispatch.ip_spoofing_check == true,
      x_forwarded_for_valid: !!valid_ips,
      remote_ip_matches_forwarded_for: valid_ips && forwarded_ips.include?(remote_ip),
      x_forwarded_proto_https: request.get_header("HTTP_X_FORWARDED_PROTO") == "https",
      x_forwarded_port_https: request.get_header("HTTP_X_FORWARDED_PORT") == "443",
      request_https: request.ssl?
    }
  end
end
