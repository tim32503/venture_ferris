# Back-office account. Replaces the legacy client-side-only auth gate
# (a frontend SDK check with zero server-side enforcement) with a real
# has_secure_password + session based login.
class Admin < ApplicationRecord
  has_secure_password

  validates :email, presence: true,
                     uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
end
