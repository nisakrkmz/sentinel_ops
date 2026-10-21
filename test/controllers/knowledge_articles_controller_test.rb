require "test_helper"

class KnowledgeArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as_nisa
    @article = KnowledgeArticle.create!(
      slug: "controller-kb-test",
      title: "Controller KB article",
      affected_service: "SAP ERP",
      category: "Enterprise Software",
      source: "synthetic_seed",
      symptoms: "An RFC call times out.",
      root_cause: "The pool is exhausted.",
      resolution_steps: [ "Review the pool." ],
      verification: "A test call succeeds.",
      approved: true
    )
    @article.rebuild_chunks!
  end

  test "knowledge base lists approved articles and labels synthetic records" do
    get knowledge_articles_url

    assert_response :success
    assert_includes response.body, "Controller KB article"
    assert_includes response.body, "Synthetic seed"
    assert_match(/semantik indeks beklemede/i, response.body)
  end

  test "article detail exposes stable citation anchors and source metadata" do
    get knowledge_article_url(@article)

    assert_response :success
    assert_select "article##{@article.slug}-symptoms"
    assert_select "[data-kb-source='synthetic_seed']"
    assert_includes response.body, "Sentetik seed içerik"
  end
end
