class CreateQuestions < ActiveRecord::Migration[7.2]
  def change
    create_table :questions do |t|
      t.integer :number, null: false
      t.integer :kind, null: false, default: 1
      t.string :title, null: false
      t.string :answer_digest, null: false
      t.text :content
      t.string :level
      t.text :hint1
      t.text :hint2
      t.text :explanation
      t.boolean :hints_enabled, null: false, default: true
      t.boolean :auto_start, null: false, default: false
      t.integer :base_score, null: false, default: 1000
      t.integer :puzzle_rows
      t.integer :puzzle_cols
      t.integer :boss_hp, null: false, default: 120
      t.integer :boss_time_limit, null: false, default: 30

      t.timestamps
    end

    add_index :questions, :number, unique: true
  end
end
