class KnowledgeArticlesController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @articles = KnowledgeArticle.approved.order(:title)
    @chunks = []
    return if @query.blank?

    result = Rag::Retriever.call(@query)
    @chunks = result.chunks
  rescue Rag::ProviderError => error
    @search_error = error.code
  end

  def show
    @article = KnowledgeArticle.approved.find_by!(slug: params[:slug])
    @chunks = @article.knowledge_chunks.order(:section)
  end
end
