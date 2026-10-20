require "digest"

module Rag
  class Indexer
    BATCH_SIZE = 16

    Result = Struct.new(:indexed, :provider, :model, keyword_init: true)

    def self.call(provider: Providers::Factory.embedding, force: false, article: nil)
      new(provider, force, article).call
    end

    def initialize(provider, force, article)
      @provider = provider
      @force = force
      @article = article
    end

    def call
      raise ProviderError.new("embedding_provider_not_configured", "Embedding provider is not configured") unless @provider.configured?

      articles.find_each do |article|
        article.rebuild_chunks!
      end
      indexed = 0
      pending = articles.flat_map do |article|
        article.knowledge_chunks.filter_map do |chunk|
          input = embedding_input(article, chunk)
          digest = Digest::SHA256.hexdigest(input)
          stale = chunk.embedding.blank? ||
            chunk.embedding_provider != @provider.provider ||
            chunk.embedding_model != @provider.model ||
            chunk.embedding_content_digest != digest
          { chunk: chunk, input: input, digest: digest } if @force || stale
        end
      end
      pending.map { |item| item.fetch(:chunk).knowledge_article }.uniq.each { |article| article.update!(indexed_at: nil) }
      pending.each_slice(BATCH_SIZE) do |batch|
        vectors = @provider.embed_many(batch.map { |item| item.fetch(:input) })
        valid_vectors = vectors.is_a?(Array) && vectors.length == batch.length &&
          vectors.all? { |vector| vector.is_a?(Array) && vector.any? && vector.all? { |value| value.is_a?(Numeric) && value.finite? } }
        dimensions = vectors.map(&:length).uniq if valid_vectors
        raise ProviderError.new("invalid_embedding_output", "Embedding provider returned invalid or inconsistent vector dimensions") unless valid_vectors && dimensions.length == 1

        batch.zip(vectors).each do |item, vector|
          item.fetch(:chunk).update!(
            embedding: vector,
            embedding_provider: @provider.provider,
            embedding_model: @provider.model,
            embedding_content_digest: item.fetch(:digest)
          )
          indexed += 1
        end
      end
      articles.find_each do |article|
        current_index = article.knowledge_chunks.any? && article.knowledge_chunks.all? do |chunk|
          chunk.embedding.present? && chunk.embedding_provider == @provider.provider && chunk.embedding_model == @provider.model
        end
        article.update!(indexed_at: Time.current) if current_index
      end
      Result.new(indexed: indexed, provider: @provider.provider, model: @provider.model)
    end

    private

    def articles
      scope = KnowledgeArticle.approved.includes(:knowledge_chunks)
      @article ? scope.where(id: @article.id) : scope
    end

    def embedding_input(article, chunk)
      [
        article.title,
        article.affected_service,
        article.configuration_item,
        article.version,
        chunk.section,
        chunk.content
      ].compact.join("\n")
    end
  end
end
