class CreateKnowledgeMemory < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_articles do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :affected_service, null: false
      t.string :category, null: false
      t.string :source, null: false
      t.string :configuration_item
      t.string :version
      t.text :symptoms, null: false
      t.text :root_cause, null: false
      t.json :resolution_steps, default: [], null: false
      t.text :verification, null: false
      t.boolean :approved, default: false, null: false
      t.integer :source_incident_id
      t.datetime :indexed_at
      t.timestamps
    end
    add_index :knowledge_articles, :slug, unique: true
    add_index :knowledge_articles, [ :approved, :affected_service ]
    add_index :knowledge_articles, :source_incident_id, unique: true
    add_foreign_key :knowledge_articles, :incidents, column: :source_incident_id

    create_table :knowledge_chunks do |t|
      t.references :knowledge_article, null: false, foreign_key: true
      t.string :chunk_id, null: false
      t.string :section, null: false
      t.text :content, null: false
      t.json :embedding
      t.timestamps
    end
    add_index :knowledge_chunks, :chunk_id, unique: true

    create_table :kb_candidates do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :submitted_by, null: false, foreign_key: { to_table: :actors }
      t.references :reviewed_by, foreign_key: { to_table: :actors }
      t.references :knowledge_article, foreign_key: true
      t.string :status, default: "pending", null: false
      t.text :root_cause, null: false
      t.json :resolution_steps, default: [], null: false
      t.text :verification, null: false
      t.timestamps
    end
    add_index :kb_candidates, [ :incident_id, :status ]
  end
end
