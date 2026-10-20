require "test_helper"

class RagIndexerTest < ActiveSupport::TestCase
  class BatchEmbeddingProvider
    attr_reader :provider, :model

    def initialize
      @provider = "test-embedding"
      @model = "test-model"
    end

    def configured?
      true
    end

    def embed_many(texts)
      texts.map { |text| [ text.length.to_f, 1.0 ] }
    end
  end

  test "indexes only approved article chunks and marks the article indexed" do
    article = KnowledgeArticle.create!(
      slug: "indexer-test-approved",
      title: "Indexable knowledge",
      affected_service: "SAP ERP",
      category: "Enterprise Software",
      source: "synthetic_seed",
      symptoms: "A batch fails.",
      root_cause: "Capacity limit.",
      resolution_steps: [ "Review capacity." ],
      verification: "Confirm the batch completes.",
      approved: true
    )
    article.rebuild_chunks!
    unapproved = KnowledgeArticle.create!(
      slug: "indexer-test-unapproved",
      title: "Not approved",
      affected_service: "SAP ERP",
      category: "Enterprise Software",
      source: "approved_human",
      symptoms: "Unreviewed symptoms.",
      root_cause: "Unreviewed cause.",
      resolution_steps: [ "Unreviewed step." ],
      verification: "Unreviewed verification.",
      approved: false
    )
    unapproved.rebuild_chunks!

    result = Rag::Indexer.call(provider: BatchEmbeddingProvider.new)

    assert_equal 4, result.indexed
    assert article.reload.indexed_at.present?
    assert article.knowledge_chunks.all? { |chunk| chunk.embedding.is_a?(Array) }
    assert article.knowledge_chunks.all? { |chunk| chunk.embedding_provider == "test-embedding" && chunk.embedding_model == "test-model" }
    assert_nil unapproved.reload.indexed_at
    assert unapproved.knowledge_chunks.all? { |chunk| chunk.embedding.nil? }
  end
end
