class Administrator < ApplicationRecord
  OWNER_EMAIL = "jeff@humani.se".freeze

  has_many :admin_sessions, dependent: :delete_all
  normalizes :email, with: ->(email){ email.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[owner admin] }
  validates :google_uid, uniqueness: true, allow_nil: true
  validate :fixed_ownership

  def owner?
    role == "owner"
  end

  def active?
    revoked_at.nil?
  end

  def access_status
    return "Revoked" unless active?
    google_uid.present? ? "Active" : "Invited"
  end

  private

  def fixed_ownership
    if (owner? && email != OWNER_EMAIL) || (email == OWNER_EMAIL && (!owner? || revoked_at.present?))
      errors.add(:base, "Ownership is reserved for #{OWNER_EMAIL} and cannot be revoked.")
    end
    if persisted? && email_changed?
      errors.add(:email, "cannot be changed; revoke access and invite a new address instead")
    end
  end
end
