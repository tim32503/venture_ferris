class CreateTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :teams do |t|
      t.string :serial_no, null: false
      t.boolean :test_mode, null: false, default: false
      t.string :name

      t.timestamps
    end

    add_index :teams, :serial_no, unique: true
  end
end
