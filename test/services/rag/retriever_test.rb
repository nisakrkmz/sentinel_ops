require "test_helper"

class RagRetrieverTest < ActiveSupport::TestCase
  class EmbeddingProvider
    attr_reader :provider, :model

    def initialize(vector: [ 0.9, 0.1 ], model: "retriever-model")
      @provider = "retriever-provider"
      @model = model
      @vector = vector
    end

    def configured?
      true
    end

    def embed(_query)
      @vector
    end
  end

  def create_indexed_article(slug:, vector:, model: "retriever-model")
    article = KnowledgeArticle.create!(
      slug: slug,
      title: slug.humanize,
      affected_service: "Cloud Infrastructure",
      category: "Cloud Infrastructure",
      source: "synthetic_seed",
      symptoms: "#{slug} symptom",
      root_cause: "#{slug} cause",
      resolution_steps: [ "#{slug} resolution" ],
      verification: "#{slug} verification",
      approved: true
    )
    article.rebuild_chunks!
    article.knowledge_chunks.each do |chunk|
      chunk.update!(
        embedding: vector,
        embedding_provider: "retriever-provider",
        embedding_model: model
      )
    end
    article.update!(indexed_at: Time.current)
    article
  end

  test "ranks approved indexed chunks by cosine similarity and excludes low-similarity evidence" do
    close = create_indexed_article(slug: "cosine-close", vector: [ 1.0, 0.0 ])
    create_indexed_article(slug: "cosine-far", vector: [ 0.0, 1.0 ])

    result = Rag::Retriever.call("find matching evidence", provider: EmbeddingProvider.new)

    assert_equal 3, result.chunks.length
    assert_equal [ close.id ], result.chunks.map { |entry| entry.fetch(:chunk).knowledge_article_id }.uniq
    assert_operator result.chunks.first.fetch(:similarity), :>, 0.99
  end

  test "reports when the existing vector index uses a different embedding model" do
    create_indexed_article(slug: "stale-vector-model", vector: [ 1.0, 0.0 ], model: "old-model")

    error = assert_raises(Rag::ProviderError) do
      Rag::Retriever.call("query", provider: EmbeddingProvider.new)
    end
    assert_equal "embedding_index_stale", error.code
  end

  test "does not silently search an empty or unindexed corpus" do
    error = assert_raises(Rag::ProviderError) do
      Rag::Retriever.call("query", provider: EmbeddingProvider.new)
    end
    assert_equal "knowledge_base_not_indexed", error.code
  end
end
