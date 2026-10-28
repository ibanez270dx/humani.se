class ResumesController < ApplicationController
  def show
    resume = Resume.current
    return head :not_found unless resume

    fresh_when strong_etag: resume.sha256, public: true, template: false,
      cache_control: { no_cache: true }
    send_data resume.pdf_data, type: "application/pdf", disposition: "inline", filename: Resume::PUBLIC_FILENAME unless performed?
  end

  def legacy
    response.cache_control[:no_cache] = true
    redirect_to resume_path, status: :found
  end
end
