class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def status
    render json: {
      version: Humanise.release_version,
      sha: Humanise.build_commit,
      environment: Rails.env,
      deployed_at: Humanise.release_created_at,
      started_at: Rails.application.config.started_at
    }
  end

  def index
  end

end
