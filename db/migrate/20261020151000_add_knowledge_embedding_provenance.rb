class AddKnowledgeEmbeddingProvenance < ActiveRecord::Migration[8.1]
  def change
    add_column :knowledge_chunks, :embedding_provider, :string
    add_column :knowledge_chunks, :embedding_model, :string
    add_column :knowledge_chunks, :embedding_content_digest, :string
    add_index :knowledge_chunks, [ :embedding_provider, :embedding_model ]
  end
end
