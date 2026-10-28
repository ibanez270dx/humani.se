class Admin::AdminsController < Admin::BaseController
  before_action :require_owner

  def index
    @admins = Admin.order(:created_at)
    @admin = Admin.new
  end

  def create
    @admin = Admin.new(params.expect(admin: [:email]))
    @admin.role = "admin"
    Admin.transaction do
      @admin.save!
      AdminAccessEvent.create!(actor: current_admin, admin: @admin, action: "invited")
    end
    redirect_to admin_admins_path, notice: "Admin invited. Share the admin URL with them."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @admins = Admin.order(:created_at)
    @admin.errors.add(:email, "has already been invited") if @admin.errors.empty?
    render :index, status: :unprocessable_entity
  end

  def update
    admin = Admin.find(params[:id])
    return head :forbidden if admin.owner?
    return head :bad_request unless %w[revoke restore].include?(params[:access])

    restoring = params[:access] == "restore"
    admin.with_lock do
      next if admin.active? == restoring

      admin.update!(revoked_at: restoring ? nil : Time.current)
      admin.admin_sessions.delete_all unless restoring
      AdminAccessEvent.create!(actor: current_admin, admin: admin, action: restoring ? "restored" : "revoked")
    end
    redirect_to admin_admins_path, notice: "Admin access updated.", status: :see_other
  end
end
