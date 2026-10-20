class PreserveKnowledgeOnSeedRebuild < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :knowledge_articles, column: :source_incident_id
    add_foreign_key :knowledge_articles, :incidents, column: :source_incident_id, on_delete: :nullify

    remove_foreign_key :kb_candidates, column: :incident_id
    add_foreign_key :kb_candidates, :incidents, on_delete: :cascade
  end
end
