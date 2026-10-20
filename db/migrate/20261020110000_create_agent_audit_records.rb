class CreateAgentAuditRecords < ActiveRecord::Migration[8.1]
  class MigrationActor < ActiveRecord::Base
    self.table_name = "actors"
  end

  def up
    create_table :actors do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :owner
      t.json :scopes, null: false, default: []
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :actors, [ :kind, :name ], unique: true

    create_table :api_tokens do |t|
      t.references :actor, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.json :scopes, null: false, default: []
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true

    create_table :decisions do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :actor, foreign_key: true
      t.string :kind, null: false
      t.string :provider, null: false
      t.string :model
      t.string :prompt_version
      t.string :input_digest
      t.json :output_json, null: false, default: {}
      t.float :confidence
      t.integer :latency_ms
      t.float :cost_estimate
      t.json :sources, null: false, default: []
      t.timestamps
    end

    create_table :handoffs do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :from_actor, null: false, foreign_key: { to_table: :actors }
      t.string :to_actor_or_group, null: false
      t.string :reason_code, null: false
      t.float :confidence
      t.json :brief, null: false, default: {}
      t.string :status, null: false, default: "open"
      t.references :resolved_by, foreign_key: { to_table: :actors }
      t.timestamps
    end

    add_reference :incidents, :opened_by_actor, foreign_key: { to_table: :actors }
    add_column :incidents, :origin, :string, null: false, default: "ui"
    add_column :incidents, :triage_status, :string, null: false, default: "pending"
    add_column :incidents, :idempotency_key, :string
    add_index :incidents, :idempotency_key, unique: true
    add_reference :timeline_events, :actor, foreign_key: true

    demo_actor = MigrationActor.create!(
      kind: "human",
      name: "Demo UI Operator (unauthenticated)",
      scopes: [],
      active: true
    )
    Incident.update_all(opened_by_actor_id: demo_actor.id)
    TimelineEvent.update_all(actor_id: demo_actor.id)
  end

  def down
    remove_reference :timeline_events, :actor
    remove_index :incidents, :idempotency_key
    remove_column :incidents, :idempotency_key
    remove_column :incidents, :triage_status
    remove_column :incidents, :origin
    remove_reference :incidents, :opened_by_actor
    drop_table :handoffs
    drop_table :decisions
    drop_table :api_tokens
    drop_table :actors
  end
end
