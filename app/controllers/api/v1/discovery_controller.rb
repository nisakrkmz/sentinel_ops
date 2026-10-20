module Api
  module V1
    class DiscoveryController < ActionController::API
      def openapi
        render file: Rails.root.join("public/api/v1/openapi.json"), content_type: "application/json"
      end

      def agent_card
        render file: Rails.root.join("public/.well-known/agent-card.json"), content_type: "application/json"
      end

      def llms
        render plain: Rails.root.join("public/llms.txt").read, content_type: "text/plain"
      end
    end
  end
end
