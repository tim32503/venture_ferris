# A Player is a member of a Team. Each team has exactly one leader and up to
# three members (see REFACTOR_PLAN.md §1.1 / §8-2).
class Player < ApplicationRecord
  MAX_LEADERS = 1
  MAX_MEMBERS = 3

  belongs_to :team
  has_many :boss_readies, dependent: :destroy

  enum :role, { leader: 0, member: 1 }, validate: true
  enum :gender, { unspecified: 0, male: 1, female: 2 }, default: :unspecified, validate: true
  # job is intentionally nullable: a player has not chosen a job yet.
  enum :job, { uncle: 0, senior: 1, netizen: 2, celebrity: 3 }, validate: { allow_nil: true }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: [ :team_id, :role ] }
  validate :team_capacity

  private

  def team_capacity
    return if team.nil? || role.blank?

    siblings = team.players.where(role: role)
    siblings = siblings.where.not(id: id) if persisted?
    count = siblings.count

    case role
    when "leader"
      errors.add(:role, "隊伍已有隊長") if count >= MAX_LEADERS
    when "member"
      errors.add(:role, "隊伍隊員已滿") if count >= MAX_MEMBERS
    end
  end
end
