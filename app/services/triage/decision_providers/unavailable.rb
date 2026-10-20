module Triage
  module DecisionProviders
    class Unavailable
      attr_reader :provider

      def initialize(reason, provider: "unconfigured")
        @reason = reason
        @provider = provider
      end

      def configured?
        false
      end

      def model
        nil
      end

      def call(_incident)
        raise ProviderError.new(@reason, "Decision provider is not configured")
      end
    end
  end
end
