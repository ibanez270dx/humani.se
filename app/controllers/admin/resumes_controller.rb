class Admin::ResumesController < Admin::BaseController
  before_action :require_owner

  def show
    @resume = Resume.current
  end

  def update
    upload = params.expect(resume: [:pdf])[:pdf]
    raise ActionController::BadRequest, "Choose one PDF file." unless upload.is_a?(ActionDispatch::Http::UploadedFile)

    Resume.publish!(io: upload, filename: upload.original_filename, uploaded_by: current_admin)
    redirect_to admin_resume_path, notice: "Resume published.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @resume = Resume.current
    @error = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end
end
