class AdminAccessEvent < ApplicationRecord
  belongs_to :actor, class_name: "Administrator"
  belongs_to :administrator
  validates :action, inclusion: { in: %w[invited revoked restored] }
end
