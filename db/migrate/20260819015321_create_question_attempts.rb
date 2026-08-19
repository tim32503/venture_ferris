class CreateQuestionAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :question_attempts do |t|
      t.references :team, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :hint_count, null: false, default: 0

      t.timestamps
    end

    add_index :question_attempts, [ :team_id, :question_id ], unique: true
  end
end
