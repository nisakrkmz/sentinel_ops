module Rag
  module Providers
    class Factory
      SUPPORTED_PROVIDERS = %w[groq nvidia huggingface gemini].freeze

      def self.embedding
        provider = ENV["EMBEDDING_PROVIDER"].to_s
        return unavailable("embedding_provider_not_configured") if provider.empty?
        return unavailable("unsupported_embedding_provider") unless SUPPORTED_PROVIDERS.include?(provider)

        Embedding.new(
          provider: provider,
          api_key: ENV["EMBEDDING_API_KEY"],
          model: ENV["EMBEDDING_MODEL"],
          endpoint: ENV["EMBEDDING_BASE_URL"]
        )
      end

      def self.relevance
        provider = ENV["DECISION_PROVIDER"].to_s
        return unavailable("decision_provider_not_configured") if provider.empty?
        return JevRelevance.new if provider == "jev"
        return unavailable("unsupported_decision_provider") unless SUPPORTED_PROVIDERS.include?(provider)

        JsonChat.new(
          provider: provider,
          api_key: ENV["DECISION_API_KEY"],
          model: ENV["DECISION_MODEL"],
          endpoint: ENV["DECISION_BASE_URL"],
          reasoning_effort: ENV["DECISION_REASONING_EFFORT"]
        )
      end

      def self.resolution
        provider = ENV["LLM_PROVIDER"].to_s
        return unavailable("llm_provider_not_configured") if provider.empty?
        return unavailable("unsupported_llm_provider") unless SUPPORTED_PROVIDERS.include?(provider)

        JsonChat.new(
          provider: provider,
          api_key: ENV["LLM_API_KEY"],
          model: ENV["LLM_MODEL"],
          endpoint: ENV["LLM_BASE_URL"],
          reasoning_effort: ENV["LLM_REASONING_EFFORT"]
        )
      end

      def self.unavailable(code)
        Unavailable.new(code)
      end
      private_class_method :unavailable
    end
  end
end
