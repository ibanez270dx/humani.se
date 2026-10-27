module Admin
  class AdministratorsController < BaseController
    before_action :require_owner

    def index
      @administrators = Administrator.order(:created_at)
      @administrator = Administrator.new
    end

    def create
      @administrator = Administrator.new(params.expect(administrator: [:email]))
      @administrator.role = "admin"
      Administrator.transaction do
        @administrator.save!
        AdminAccessEvent.create!(actor: current_administrator, administrator: @administrator, action: "invited")
      end
      redirect_to admin_administrators_path, notice: "Administrator invited. Share the admin URL with them."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      @administrators = Administrator.order(:created_at)
      @administrator.errors.add(:email, "has already been invited") if @administrator.errors.empty?
      render :index, status: :unprocessable_entity
    end

    def update
      administrator = Administrator.find(params[:id])
      return head :forbidden if administrator.owner?

      administrator.with_lock do
        restoring = params[:access] == "restore"
        administrator.update!(revoked_at: restoring ? nil : Time.current)
        administrator.admin_sessions.delete_all unless restoring
        AdminAccessEvent.create!(actor: current_administrator, administrator: administrator, action: restoring ? "restored" : "revoked")
      end
      redirect_to admin_administrators_path, notice: "Administrator access updated.", status: :see_other
    end
  end
end
