class ProxyChecksController < ApplicationController
  def show
    response.set_header("Cache-Control", "no-store")
    response.set_header("X-Robots-Tag", "noindex, nofollow")
    nonce = request.get_header("HTTP_X_HUMANISE_PROXY_NONCE").to_s
    return head :bad_request unless /\A[0-9a-f]{32}\z/.match?(nonce)

    checks = ProxyHeaderCheck.call(request)
    render json: {
      schema: 1,
      nonce: nonce,
      sha: Humanise.build_commit,
      environment: Rails.env,
      actionpack_version: ActionPack::VERSION::STRING,
      forwarded_present: request.get_header("HTTP_FORWARDED").present?,
      checks: checks
    }, status: checks.values.all?{ |value| value == true } ? :ok : :service_unavailable
  end
end
