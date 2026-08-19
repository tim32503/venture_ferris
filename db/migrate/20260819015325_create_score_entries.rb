class CreateScoreEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :score_entries do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :question_number, null: false
      t.integer :question_score, null: false, default: 0
      t.integer :time_score, null: false, default: 0
      t.integer :hint_score, null: false, default: 0
      t.integer :boss_score, null: false, default: 0
      t.integer :job_score, null: false, default: 0
      t.integer :total_score, null: false, default: 0

      t.timestamps
    end

    add_index :score_entries, [ :team_id, :question_number ], unique: true
  end
end
