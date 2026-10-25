class HealthController < ActionController::API
  # Public, credential-free readiness signal for Render and the demo checklist.
  # Reports only whether each provider is configured, never keys or endpoints.
  def show
    render json: {
      status: "ok",
      database: database_state,
      providers: {
        decision: provider_state(Triage::DecisionProviders::Factory.build),
        embedding: provider_state(Rag::Providers::Factory.embedding),
        resolution: provider_state(Rag::Providers::Factory.resolution),
        page_agent: PageAgentProxy.configured? ? "configured" : "disabled"
      },
      knowledge_base: {
        approved_articles: KnowledgeArticle.approved.count,
        indexed_articles: KnowledgeArticle.approved.where.not(indexed_at: nil).count
      }
    }
  rescue Triage::ProviderError
    render json: { status: "ok", providers: { decision: "unsupported" } }
  end

  private

  def database_state
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1 ? "ok" : "unavailable"
  rescue ActiveRecord::ActiveRecordError
    "unavailable"
  end

  def provider_state(provider)
    return "disabled" unless provider.configured?

    "#{provider.provider}:#{provider.model}"
  end
end
