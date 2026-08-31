# 7b + 7d (docs/SCHEMA_REDESIGN.md §2-7b / §2-7d, scoped by §7):
#
# 7b — "two teammates may not hold the same job" was enforced only by a
# read-then-write check in Game::JobsController, so two players submitting at
# the same moment could both take one job. That is not cosmetic: jobs feed
# ScoreCalculator's senior/celebrity bonuses and the uncle boss-time bonus, so
# the race changes the game's results. A partial unique index is the only
# thing that actually closes it.
#
# 7d — the old `[team_id, role, email]` key let one email hold both the leader
# seat and a member seat on the same team, consuming two of the four slots.
# The 2018 dump has zero such rows out of 573 players, so this was never
# intended. This is the one deliberate behavior change in this batch: the
# second registration is now refused with error code 01006, which points the
# player at the existing account-transfer flow.
class TightenPlayerUniqueness < ActiveRecord::Migration[7.2]
  def up
    add_index :players, [ :team_id, :job ],
              unique: true,
              where: "job IS NOT NULL",
              name: "index_players_on_team_id_and_job"

    remove_index :players, name: "index_players_on_team_role_email"
    add_index :players, [ :team_id, :email ], unique: true, name: "index_players_on_team_id_and_email"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
