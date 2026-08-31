# M4 (docs/SCHEMA_REDESIGN.md §2-2 / §3): the same fix as M3, applied to the
# settlement ledger — and the worse of the two cases, because `ScoreEntry`
# did not even declare `belongs_to :question`: a bare integer was the only
# link the whole scoring table had to the questions it scored.
#
# The "a ledger should outlive its questions" objection argues *for* the
# foreign key rather than against it: `add_foreign_key` defaults to RESTRICT,
# so deleting a scored question now fails loudly instead of orphaning rows,
# whereas `Question has_many :question_attempts, dependent: :destroy` already
# meant deleting one shredded that team's history.
class AddQuestionRefToScoreEntries < ActiveRecord::Migration[7.2]
  def up
    add_reference :score_entries, :question, foreign_key: true

    execute <<~SQL.squish
      UPDATE score_entries
         SET question_id = (SELECT id FROM questions WHERE questions.number = score_entries.question_number)
    SQL

    # Development-only cleanup; a score row that matches no question is
    # precisely what this migration makes unrepresentable. `score_entries`
    # has no child tables, so nothing has to be deleted first.
    execute "DELETE FROM score_entries WHERE question_id IS NULL"

    change_column_null :score_entries, :question_id, false

    remove_index :score_entries, name: "index_score_entries_on_team_id_and_question_number"
    add_index :score_entries, [ :team_id, :question_id ], unique: true

    remove_column :score_entries, :question_number
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
