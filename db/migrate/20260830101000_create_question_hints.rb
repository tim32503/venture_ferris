# M1 (docs/SCHEMA_REDESIGN.md §2-4 / §3): `hint1`/`hint2` are a textbook
# repeating group, and `hints_enabled` is a stored derived value — every one
# of the 11 seeded questions has `hints_enabled == hint1.present?`. Both go
# away in favor of a `question_hints` child table, after which "this question
# has no hint rows" is the *only* representation of "no hints", so the
# derived flag can no longer drift from the data it was derived from.
#
# Irreversible on purpose: `down` cannot restore the hint1/hint2 split for a
# question that grew a third hint row, and this is a pre-launch project with
# no production data (the real path is `db:reset && db:seed`).
class CreateQuestionHints < ActiveRecord::Migration[7.2]
  def up
    create_table :question_hints do |t|
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :question_hints, [ :question_id, :position ], unique: true

    # Backfill straight in SQL (no model constants — a future rename of
    # Question/QuestionHint must not break this migration). Blank hint text
    # is dropped rather than migrated: the legacy site let players spend
    # (and be charged for) hints on questions 1/2/8/9 whose hint columns
    # were empty strings, and `position` is renumbered densely with
    # `row_number()` so a question with only `hint2` filled still starts at
    # position 1.
    execute <<~SQL.squish
      INSERT INTO question_hints (question_id, position, content, created_at, updated_at)
      SELECT question_id,
             row_number() OVER (PARTITION BY question_id ORDER BY source_position),
             content,
             now(),
             now()
      FROM (
        SELECT id AS question_id, 1 AS source_position, hint1 AS content
          FROM questions WHERE hint1 IS NOT NULL AND btrim(hint1) <> ''
        UNION ALL
        SELECT id AS question_id, 2 AS source_position, hint2 AS content
          FROM questions WHERE hint2 IS NOT NULL AND btrim(hint2) <> ''
      ) AS legacy_hints
    SQL

    remove_columns :questions, :hint1, :hint2, :hints_enabled
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
