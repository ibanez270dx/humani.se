class AdminSession < ApplicationRecord
  COOKIE_NAME = (Rails.env.production? ? "__Host-humanise_admin_session" : "admin_session").freeze

  belongs_to :admin
  validates :token_digest, :expires_at, presence: true

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end
end
