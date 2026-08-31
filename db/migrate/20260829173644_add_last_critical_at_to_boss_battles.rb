# Server-side anti-cheat throttle for the client-claimed `critical` attack
# param (see Game::BossesController#attacks / BossBattle::CRITICAL_THROTTLE_SECONDS):
# a client can claim any attack was a "weak point" hit, so the server only
# honors that claim when at least CRITICAL_THROTTLE_SECONDS have passed since
# the last accepted critical — otherwise the attack is scored as a normal hit.
class AddLastCriticalAtToBossBattles < ActiveRecord::Migration[7.2]
  def change
    add_column :boss_battles, :last_critical_at, :datetime
  end
end
