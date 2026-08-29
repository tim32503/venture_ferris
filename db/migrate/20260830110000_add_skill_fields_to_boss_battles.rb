# Backing fields for the four job active skills (docs/JOB_SKILLS_DESIGN.md):
#
#   - `bonus_time_seconds`: 阿北's 倚老賣老 adds to this battle's time limit
#     on top of the existing passive (Game::BossesHelper#boss_time_limit_seconds)
#     and starts at 0 so untouched battles compute the same limit as before.
#   - `spotlight_until`: 罔美's 聚光燈 opens a window (until this timestamp)
#     during which BossBattle#critical_ready? honors a claimed critical
#     regardless of the normal CRITICAL_THROTTLE_SECONDS gate. NULL means no
#     spotlight is active — the pre-existing throttle behavior is unchanged.
class AddSkillFieldsToBossBattles < ActiveRecord::Migration[7.2]
  def change
    add_column :boss_battles, :bonus_time_seconds, :integer, default: 0, null: false
    add_column :boss_battles, :spotlight_until, :datetime
  end
end
