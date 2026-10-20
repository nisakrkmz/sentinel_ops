require "yaml"

module Rag
  class Retriever
    Result = Struct.new(:chunks, :query_vector, :latency_ms, keyword_init: true)

    def self.call(query, provider: Providers::Factory.embedding, limit: nil)
      new(query, provider, limit).call
    end

    def initialize(query, provider, limit)
      @query = query
      @provider = provider
      @limit = limit || settings.fetch("retrieval_limit")
    end

    def call
      raise ProviderError.new("invalid_embedding_input", "Search query must contain text") unless @query.is_a?(String) && @query.present?
      raise ProviderError.new("embedding_provider_not_configured", "Embedding provider is not configured") unless @provider.configured?

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      unless KnowledgeArticle.approved.where.not(indexed_at: nil).exists?
        raise ProviderError.new("knowledge_base_not_indexed", "Approved knowledge articles have not been embedded")
      end

      vector = @provider.embed(@query)
      @embedding_latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      candidates = KnowledgeChunk.joins(:knowledge_article)
        .where(knowledge_articles: { approved: true })
        .where.not(knowledge_articles: { indexed_at: nil })
        .where(embedding_provider: @provider.provider, embedding_model: @provider.model)
        .where.not(embedding: nil)
        .includes(:knowledge_article)
      if candidates.empty?
        raise ProviderError.new("embedding_index_stale", "Knowledge chunks are not indexed with the configured embedding provider and model")
      end

      scored = candidates.map do |chunk|
        raise ProviderError.new("embedding_dimension_mismatch", "Stored knowledge vectors do not match the configured embedding model") unless chunk.embedding.length == vector.length

        [ chunk, cosine_similarity(vector, chunk.embedding) ]
      end
      minimum_similarity = settings.fetch("minimum_similarity")
      ranked = scored.select { |_chunk, score| score >= minimum_similarity }
        .sort_by { |_chunk, score| -score }
        .first(@limit)
        .map do |chunk, score|
          { chunk: chunk, similarity: score.round(6) }
        end

      Result.new(chunks: ranked, query_vector: vector, latency_ms: @embedding_latency_ms)
    end

    def self.settings
      @settings ||= YAML.safe_load_file(
        Rails.root.join("config/rag.yml"),
        aliases: true
      ).fetch(Rails.env).deep_stringify_keys.freeze
    end
    private_class_method :settings

    private

    def settings
      self.class.send(:settings)
    end

    def cosine_similarity(left, right)
      dot = left.zip(right).sum { |a, b| a * b }
      left_norm = Math.sqrt(left.sum { |value| value * value })
      right_norm = Math.sqrt(right.sum { |value| value * value })
      return 0.0 if left_norm.zero? || right_norm.zero?

      dot / (left_norm * right_norm)
    end
  end
end
