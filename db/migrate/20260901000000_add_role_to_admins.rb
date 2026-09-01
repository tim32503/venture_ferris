class AddRoleToAdmins < ActiveRecord::Migration[7.2]
  def change
    # default: 0 (operator) so every existing admin account keeps full
    # read/write access after this migration runs — nobody is silently
    # downgraded to viewer.
    add_column :admins, :role, :integer, default: 0, null: false
  end
end
