class RenameAdministratorsToAdmins < ActiveRecord::Migration[8.1]
  def change
    rename_table :administrators, :admins
    rename_column :admin_sessions, :administrator_id, :admin_id
    rename_column :admin_access_events, :administrator_id, :admin_id
    reversible do |direction|
      direction.up do
        execute "ALTER TABLE admins RENAME CONSTRAINT administrator_roles TO admin_roles"
      end
      direction.down do
        execute "ALTER TABLE admins RENAME CONSTRAINT admin_roles TO administrator_roles"
      end
    end
  end
end
