class CreateRewardCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :reward_codes do |t|
      t.string :code, null: false
      t.boolean :test_mode, null: false, default: false
      t.string :player_email
      t.datetime :claimed_at

      t.timestamps
    end

    add_index :reward_codes, :code, unique: true
    add_index :reward_codes, :player_email
  end
end
