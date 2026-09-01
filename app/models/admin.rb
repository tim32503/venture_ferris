# Back-office account. Replaces the legacy client-side-only auth gate
# (a frontend SDK check with zero server-side enforcement) with a real
# has_secure_password + session based login.
class Admin < ApplicationRecord
  has_secure_password

  # operator (default) has full read/write access; viewer is the public
  # portfolio-showcase account — it can log in and browse every back-office
  # page, but every write is refused server-side (Admin::BaseController).
  enum :role, { operator: 0, viewer: 1 }, default: :operator, validate: true

  validates :email, presence: true,
                     uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
end
