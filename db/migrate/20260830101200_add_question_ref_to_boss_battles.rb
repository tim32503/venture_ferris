# M3 (docs/SCHEMA_REDESIGN.md §2-1 / §3): `boss_battles.boss_no` was a real
# foreign key that was never declared as one. `ScoreEntry.record_pending_for!`
# joined on it by hand (`find_by(boss_no: question.number)`), and nothing at
# the database level stopped `BossBattle.create!(team:, boss_no: 99)` — the
# old model tests did exactly that, against question numbers that did not
# exist.
#
# The unique key stays keyed on the *question*, not the boss: Q10 and Q11 are
# two separate fights that happen to share one monster, so a team legitimately
# has two battle rows pointing at the same `Boss`.
class AddQuestionRefToBossBattles < ActiveRecord::Migration[7.2]
  def up
    add_reference :boss_battles, :question, foreign_key: true

    execute <<~SQL.squish
      UPDATE boss_battles
         SET question_id = (SELECT id FROM questions WHERE questions.number = boss_battles.boss_no)
    SQL

    # Development-only cleanup: any battle whose `boss_no` matched no question
    # is exactly the dangling row this migration exists to make impossible, so
    # it cannot be backfilled — drop it. Children first, because the foreign
    # keys are RESTRICT.
    execute <<~SQL.squish
      DELETE FROM boss_readies
       WHERE boss_battle_id IN (SELECT id FROM boss_battles WHERE question_id IS NULL)
    SQL
    execute "DELETE FROM boss_battles WHERE question_id IS NULL"

    change_column_null :boss_battles, :question_id, false

    remove_index :boss_battles, name: "index_boss_battles_on_team_id_and_boss_no"
    add_index :boss_battles, [ :team_id, :question_id ], unique: true

    remove_column :boss_battles, :boss_no
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
