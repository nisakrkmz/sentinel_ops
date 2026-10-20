class KbCandidate < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  enum :status, STATUSES.index_with(&:itself), validate: true

  belongs_to :incident
  belongs_to :submitted_by, class_name: "Actor"
  belongs_to :reviewed_by, class_name: "Actor", optional: true
  belongs_to :knowledge_article, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :root_cause, :verification, presence: true
  validate :resolution_steps_are_strings

  scope :pending_review, -> { where(status: "pending") }

  def approve!(actor)
    transaction do
      article = KnowledgeArticle.create!(
        slug: "incident-#{incident.number.downcase}",
        title: incident.short_description,
        affected_service: incident.service_affected,
        category: incident.category,
        source: "approved_human",
        symptoms: incident.description,
        root_cause: root_cause,
        resolution_steps: resolution_steps,
        verification: verification,
        approved: true,
        source_incident: incident
      )
      article.rebuild_chunks!
      update!(status: "approved", reviewed_by: actor, knowledge_article: article)
    end
  end

  def reject!(actor)
    update!(status: "rejected", reviewed_by: actor)
  end

  private

  def resolution_steps_are_strings
    valid = resolution_steps.is_a?(Array) && resolution_steps.any? && resolution_steps.all? { |step| step.is_a?(String) && step.present? }
    errors.add(:resolution_steps, "must be a non-empty array of strings") unless valid
  end
end
