# Records that a player has spent their job's Boss-fight active skill for a
# given battle (docs/JOB_SKILLS_DESIGN.md). The DB-level unique index on
# [boss_battle_id, player_id] (not just this validation) is what actually
# enforces "once per player per battle" — see Game::BossesController#skill,
# which rescues the race-loser the same way Game::JobsController#update does
# for the [team_id, job] index.
class BossSkillUse < ApplicationRecord
  belongs_to :boss_battle
  belongs_to :player

  validates :skill, presence: true, inclusion: { in: Player.jobs.keys }
  validates :player_id, uniqueness: { scope: :boss_battle_id }

  # Only 鞋姊 (senior)'s 醍醐灌頂 stays unconsumed after activation — every
  # other job's effect applies immediately, so their rows are created with
  # `consumed_at` already set (see Game::BossesController#apply_skill!).
  def pending?
    consumed_at.blank?
  end
end
