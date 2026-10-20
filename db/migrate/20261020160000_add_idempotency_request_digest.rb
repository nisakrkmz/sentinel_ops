class AddIdempotencyRequestDigest < ActiveRecord::Migration[8.1]
  def change
    add_column :incidents, :idempotency_request_digest, :string
    add_index :incidents, :idempotency_request_digest
  end
end
