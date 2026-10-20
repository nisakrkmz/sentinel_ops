module Api
  module V1
    class KnowledgeController < BaseController
      def search
        return unless require_scope!("kb:read")

        query = params[:q]
        unless query.is_a?(String) && query.present?
          return render_error(code: "invalid_query", message: "A non-empty q parameter is required.", status: :bad_request, field_errors: { q: [ "is required" ] })
        end

        result = Rag::Retriever.call(query)
        render json: {
          data: result.chunks.map do |entry|
            chunk = entry.fetch(:chunk)
            article = chunk.knowledge_article
            {
              chunk_id: chunk.chunk_id,
              title: article.title,
              source: article.source,
              service: article.affected_service,
              section: chunk.section,
              content: chunk.content,
              similarity: entry.fetch(:similarity)
            }
          end
        }
      rescue Rag::ProviderError => error
        render_error(
          code: error.code,
          message: error.message,
          status: :service_unavailable,
          retryable: true
        )
      end
    end
  end
end
