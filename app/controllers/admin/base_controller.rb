class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :private_response
  before_action :require_admin
  helper_method :current_admin

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
    @current_admin_session = AdminSession.includes(:admin).find_by(token_digest: AdminSession.digest(token)) if token.present?
  end

  def current_admin
    login = current_admin_session
    login.admin if login && login.expires_at.future? && login.admin.active?
  end

  def require_admin
    redirect_to admin_sign_in_path unless current_admin
  end

  def require_owner
    head :forbidden unless current_admin.owner?
  end
end
