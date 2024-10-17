class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def status
    render json: {
      app_id: Humanise.app_id,
      app_name: Humanise.app_name,
      hostname: `hostname`.squish,
      environment: Rails.env,
      ruby_version: `ruby -v`.squish,
      rails_version: Rails.version,
      release_version: Humanise.release_version,
      released_created_at: Humanise.released_created_at,
      build_commit: Humanise.build_commit,
      build_description: Humanise.build_description,
      deployed_at: File.mtime(Rails.root)
    }
  end

  def index
  end

end
