require "test_helper"

class KbCandidateTest < ActiveSupport::TestCase
  setup do
    @actor = Actor.demo_ui_operator
    @incident = Incident.create!(
      short_description: "VPN pool capacity exhausted",
      description: "Remote users cannot connect.",
      service_affected: "Global VPN Gateway",
      category: "Network Infrastructure",
      state: :resolved
    )
    @candidate = KbCandidate.create!(
      incident: @incident,
      submitted_by: @actor,
      root_cause: "The configured address pool was exhausted.",
      resolution_steps: [ "Verify active sessions.", "Apply the approved pool change." ],
      verification: "A test user connected and received an address."
    )
  end

  test "approval creates an approved article and structured chunks with no fabricated embedding" do
    @candidate.approve!(@actor)

    assert_equal "approved", @candidate.reload.status
    article = @candidate.knowledge_article
    assert article.approved?
    assert_equal "approved_human", article.source
    assert_equal @incident.id, article.source_incident_id
    assert_equal 4, article.knowledge_chunks.count
    assert article.knowledge_chunks.all? { |chunk| chunk.embedding.nil? }
  end

  test "rejection keeps the candidate out of the approved knowledge base" do
    @candidate.reject!(@actor)

    assert_equal "rejected", @candidate.reload.status
    assert_nil @candidate.knowledge_article
    assert_empty KnowledgeArticle.approved
  end

  test "incident rebuild preserves resolved knowledge and removes its pending candidate" do
    article = KnowledgeArticle.create!(
      slug: "resolved-incident-#{@incident.id}",
      title: "Resolved incident memory",
      affected_service: "Global VPN Gateway",
      category: "Network Infrastructure",
      source: "resolved_incident",
      source_incident: @incident,
      symptoms: "A resolved incident symptom.",
      root_cause: "A verified root cause.",
      resolution_steps: [ "Apply the verified resolution." ],
      verification: "Confirm the service is restored.",
      approved: true
    )

    TimelineEvent.where(incident_id: @incident.id).delete_all
    Decision.where(incident_id: @incident.id).delete_all
    Handoff.where(incident_id: @incident.id).delete_all
    Incident.where(id: @incident.id).delete_all

    assert_nil article.reload.source_incident_id
    assert_not KbCandidate.exists?(id: @candidate.id)
  end
end
