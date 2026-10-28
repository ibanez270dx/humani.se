class AdminAccessEvent < ApplicationRecord
  belongs_to :actor, class_name: "Admin", inverse_of: :performed_admin_access_events
  belongs_to :admin
  validates :action, inclusion: { in: %w[invited revoked restored] }
end
