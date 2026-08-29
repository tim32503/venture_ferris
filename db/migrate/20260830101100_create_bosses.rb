# M2 (docs/SCHEMA_REDESIGN.md §2-3 / §3): questions and bosses are not 1:1.
# Q10 ("摩天輪F1") and Q11 ("摩天輪F2") are two fights against the *same*
# 摩天輪魔王 — `mon10.gif` never existed — so 10 bosses cover 11 questions.
# That relationship currently lives in three helper methods plus two magic
# constants; here it becomes one foreign key value shared by two rows.
#
# `boss_hp`/`boss_time_limit` deliberately stay on `questions`: they are
# per-fight parameters, not properties of the monster (Q10 and Q11 already
# differ in `base_score`, 1000 vs 3000). Moving them would force the two
# phases to share a difficulty — a behavior change, not normalization.
#
# The `bosses` rows are inserted here so an existing development database can
# reach `boss_id NOT NULL`, but db/seeds.rb owns them for real: the test
# database is built with `schema:load`, which never runs this file.
class CreateBosses < ActiveRecord::Migration[7.2]
  # question number => sprite. 1..9 map to their own sprite; 10 and 11 share
  # mon11 (phase 1 renders it dimmed/smaller, phase 2 at full colour).
  BOSS_SPRITE_FOR_QUESTION = (1..9).to_h { |n| [ n, format("mon%02d", n) ] }
                                    .merge(10 => "mon11", 11 => "mon11")
                                    .freeze
  BOSS_PHASE_FOR_QUESTION = { 10 => 1, 11 => 2 }.freeze

  def up
    create_table :bosses do |t|
      t.string :sprite, null: false

      t.timestamps
    end

    add_index :bosses, :sprite, unique: true

    add_reference :questions, :boss, foreign_key: true
    add_column :questions, :boss_phase, :integer

    BOSS_SPRITE_FOR_QUESTION.values.uniq.each do |sprite|
      execute <<~SQL.squish
        INSERT INTO bosses (sprite, created_at, updated_at)
        VALUES (#{quote(sprite)}, now(), now())
        ON CONFLICT (sprite) DO NOTHING
      SQL
    end

    BOSS_SPRITE_FOR_QUESTION.each do |number, sprite|
      phase = BOSS_PHASE_FOR_QUESTION[number]

      execute <<~SQL.squish
        UPDATE questions
           SET boss_id = (SELECT id FROM bosses WHERE sprite = #{quote(sprite)}),
               boss_phase = #{phase || 'NULL'}
         WHERE number = #{number}
      SQL
    end

    change_column_null :questions, :boss_id, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
