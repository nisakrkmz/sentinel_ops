require "test_helper"

class KnowledgeArticleTest < ActiveSupport::TestCase
  def article
    KnowledgeArticle.create!(
      slug: "test-sap-work-pool",
      title: "SAP work process capacity",
      affected_service: "SAP ERP",
      category: "Enterprise Software",
      source: "synthetic_seed",
      symptoms: "RFC timeout during batch processing.",
      root_cause: "Concurrent jobs exhausted available workers.",
      resolution_steps: [ "Inspect work process utilization.", "Stagger approved jobs." ],
      verification: "Confirm RFC requests complete.",
      approved: true
    )
  end

  test "builds four stable structured chunks and clears stale vectors when content changes" do
    record = article
    record.rebuild_chunks!
    record.knowledge_chunks.update_all(embedding: [ 0.25, 0.75 ])

    assert_equal %w[resolution root-cause symptoms verification], record.knowledge_chunks.order(:section).pluck(:section)
    assert_equal "test-sap-work-pool-symptoms", record.knowledge_chunks.find_by!(section: "symptoms").chunk_id

    record.update!(symptoms: "A different symptom.")
    record.rebuild_chunks!

    assert_nil record.knowledge_chunks.find_by!(section: "symptoms").embedding
    assert_equal [ 0.25, 0.75 ], record.knowledge_chunks.find_by!(section: "root-cause").embedding
  end

  test "rejects synthetic or approved articles without structured resolution steps" do
    record = KnowledgeArticle.new(
      slug: "empty-steps",
      title: "Missing steps",
      affected_service: "SAP ERP",
      category: "Enterprise Software",
      source: "synthetic_seed",
      symptoms: "Symptom",
      root_cause: "Cause",
      resolution_steps: [],
      verification: "Not verified",
      approved: true
    )

    assert_not record.valid?
    assert_includes record.errors[:resolution_steps], "must be a non-empty array of strings"
  end
end
