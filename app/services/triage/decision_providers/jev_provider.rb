module Triage
  module DecisionProviders
    class JevProvider < Unavailable
      def initialize
        super("jev_contract_unverified", provider: "jev")
      end
    end
  end
end
