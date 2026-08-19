class CreateBossReadies < ActiveRecord::Migration[7.2]
  def change
    create_table :boss_readies do |t|
      t.references :boss_battle, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end

    add_index :boss_readies, [ :boss_battle_id, :player_id ], unique: true, name: "index_boss_readies_on_battle_and_player"
  end
end
