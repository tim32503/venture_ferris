# Idempotent "ready" mark for a player within a boss battle. This replaces
# the legacy BOSS_LOG.READY_COUNT counter, which had no idempotency and could
# be inflated by page refreshes. `ready_count` on BossBattle is derived from
# counting rows here instead.
class BossReady < ApplicationRecord
  belongs_to :boss_battle
  belongs_to :player

  validates :player_id, uniqueness: { scope: :boss_battle_id }
end
