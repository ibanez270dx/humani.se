class CreateAdminAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :administrators do |t|
      t.string :email, null: false
      t.string :role, null: false, default: "admin"
      t.string :google_uid
      t.string :name
      t.datetime :last_signed_in_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :administrators, :email, unique: true
    add_index :administrators, :google_uid, unique: true
    add_check_constraint :administrators, "role IN ('owner', 'admin')", name: "administrator_roles"

    create_table :admin_sessions do |t|
      t.references :administrator, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :admin_sessions, :token_digest, unique: true

    create_table :admin_access_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :administrators }
      t.references :administrator, null: false, foreign_key: true
      t.string :action, null: false
      t.timestamps
    end
  end
end
