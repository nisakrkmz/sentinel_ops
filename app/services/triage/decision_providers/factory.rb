module Triage
  module DecisionProviders
    class Factory
      SUPPORTED_PROVIDERS = %w[groq nvidia huggingface].freeze

      def self.build
        provider = ENV["DECISION_PROVIDER"].to_s
        return Unavailable.new("provider_not_configured") if provider.empty?
        return JevProvider.new if provider == "jev"
        unless SUPPORTED_PROVIDERS.include?(provider)
          raise ProviderError.new("unsupported_provider", "DECISION_PROVIDER is not supported")
        end

        OpenAiCompatible.new(
          provider: provider,
          api_key: ENV["DECISION_API_KEY"],
          model: ENV["DECISION_MODEL"],
          endpoint: ENV["DECISION_BASE_URL"]
        )
      end
    end
  end
end
