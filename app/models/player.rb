# A Player is a member of a Team. Each team has exactly one leader and up to
# three members (see REFACTOR_PLAN.md §1.1 / §8-2).
class Player < ApplicationRecord
  # MAX_LEADERS is expressible as a unique index and MAX_MEMBERS is not (a
  # count ceiling needs a trigger, which this project deliberately does not
  # introduce), so the two limits are enforced at different layers — see
  # docs/SCHEMA_REDESIGN.md §5-7. `#team_capacity` below is the one that
  # covers both in Ruby.
  MAX_LEADERS = 1
  MAX_MEMBERS = 3

  belongs_to :team
  has_many :boss_readies, dependent: :destroy
  # Mirrors `boss_readies` above: without this, destroying a Player who has
  # activated a Boss-fight skill (docs/JOB_SKILLS_DESIGN.md) hits the
  # `boss_skill_uses.player_id` FK instead of cascading — found by manually
  # cleaning up dev-server demo data created while verifying this feature.
  has_many :boss_skill_uses, dependent: :destroy

  enum :role, { leader: 0, member: 1 }, validate: true
  enum :gender, { unspecified: 0, male: 1, female: 2 }, default: :unspecified, validate: true
  # job is intentionally nullable: a player has not chosen a job yet.
  enum :job, { uncle: 0, senior: 1, netizen: 2, celebrity: 3 }, validate: { allow_nil: true }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # Scoped to the team alone, not to [team, role]: one email is one seat on a
  # team (docs/SCHEMA_REDESIGN.md §2-7d). This must mirror the
  # `index_players_on_team_id_and_email` unique index exactly — a looser
  # validation would let `save` pass Ruby and then blow up in PostgreSQL.
  validates :email, uniqueness: { scope: :team_id }
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
