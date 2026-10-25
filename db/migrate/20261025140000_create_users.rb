class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :password_digest, null: false
      t.references :actor, null: false, foreign_key: true, index: { unique: true }
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
