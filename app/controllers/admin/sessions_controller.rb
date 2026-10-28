class Admin::SessionsController < Admin::BaseController
  skip_before_action :require_admin, only: %i[new create]

  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    unless auth && auth["provider"] == "google_oauth2" && auth.dig("extra", "raw_info", "email_verified") == true && auth["uid"].present? && auth.dig("info", "email").present?
      return deny_access
    end

    email = auth.dig("info", "email").strip.downcase
    admin = Admin.find_by(google_uid: auth["uid"]) || Admin.find_by(email: email)
    return deny_access unless admin

    admin.with_lock do
      return deny_access unless admin.active?
      return deny_access if admin.google_uid.present? && admin.google_uid != auth["uid"]
      admin.update!(google_uid: auth["uid"], name: auth.dig("info", "name"), last_signed_in_at: Time.current)
      current_admin_session&.destroy!
      reset_session
      token = SecureRandom.urlsafe_base64(32)
      expires_at = 7.days.from_now
      admin.admin_sessions.create!(token_digest: AdminSession.digest(token), expires_at: expires_at)
      cookies[AdminSession::COOKIE_NAME] = { value: token, expires: expires_at, secure: Rails.env.production?, httponly: true, same_site: :lax }
    end
    redirect_to admin_root_path
  rescue ActiveRecord::RecordNotUnique
    deny_access
  end

  def destroy
    current_admin_session&.destroy!
    cookies.delete(AdminSession::COOKIE_NAME)
    reset_session
    redirect_to admin_sign_in_path, status: :see_other
  end

  private

  def deny_access
    current_admin_session&.destroy!
    cookies.delete(AdminSession::COOKIE_NAME)
    reset_session
    redirect_to admin_sign_in_path, alert: "This Google account does not have access. Contact the site owner."
  end
end
