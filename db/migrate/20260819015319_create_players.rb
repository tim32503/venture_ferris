class CreatePlayers < ActiveRecord::Migration[7.2]
  def change
    create_table :players do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :role, null: false
      t.string :email, null: false
      t.integer :job
      t.string :name
      t.integer :gender, null: false, default: 0
      t.string :mobile

      t.timestamps
    end

    add_index :players, [ :team_id, :role, :email ], unique: true, name: "index_players_on_team_role_email"
  end
end
