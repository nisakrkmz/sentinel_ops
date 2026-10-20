module Rag
  module Providers
    class Unavailable
      attr_reader :provider, :model, :error_code

      def initialize(error_code)
        @provider = "unconfigured"
        @model = nil
        @error_code = error_code
      end

      def configured?
        false
      end

      def embed(_text)
        raise ProviderError.new(error_code, "RAG provider is not configured")
      end

      def call(**_arguments)
        raise ProviderError.new(error_code, "RAG provider is not configured")
      end
    end
  end
end
