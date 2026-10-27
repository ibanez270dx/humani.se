module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :private_response
    before_action :require_administrator
    helper_method :current_administrator

    content_security_policy do |policy|
      policy.form_action :self, "https://accounts.google.com"
    end

    private

    def private_response
      response.set_header("Cache-Control", "no-store")
      response.set_header("X-Robots-Tag", "noindex, nofollow")
    end

    def current_admin_session
      return @current_admin_session if defined?(@current_admin_session)
      token = cookies[AdminSession::COOKIE_NAME]
      @current_admin_session = AdminSession.includes(:administrator).find_by(token_digest: AdminSession.digest(token)) if token.present?
    end

    def current_administrator
      login = current_admin_session
      login.administrator if login && login.expires_at.future? && login.administrator.active?
    end

    def require_administrator
      redirect_to admin_sign_in_path unless current_administrator
    end

    def require_owner
      head :forbidden unless current_administrator.owner?
    end
  end
end
