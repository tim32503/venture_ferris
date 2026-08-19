class CreateBossBattles < ActiveRecord::Migration[7.2]
  def change
    create_table :boss_battles do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :boss_no, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :attack_count, null: false, default: 0
      t.integer :hp, null: false, default: 120

      t.timestamps
    end

    add_index :boss_battles, [ :team_id, :boss_no ], unique: true
  end
end
