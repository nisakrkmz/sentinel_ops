class KnowledgeArticle < ApplicationRecord
  SOURCES = %w[resolved_incident synthetic_seed approved_human].freeze

  belongs_to :source_incident, class_name: "Incident", optional: true
  has_many :knowledge_chunks, dependent: :destroy
  has_many :kb_candidates, dependent: :nullify

  validates :slug, :title, :affected_service, :category, :symptoms, :root_cause, :verification, presence: true
  validates :slug, uniqueness: true
  validates :source, inclusion: { in: SOURCES }
  validate :resolution_steps_are_strings

  scope :approved, -> { where(approved: true) }

  def to_param
    slug
  end

  def rebuild_chunks!
    changed = false
    sections.each do |section, content|
      chunk = knowledge_chunks.find_or_initialize_by(section: section)
      chunk_attributes = { chunk_id: "#{slug}-#{section}", content: content }
      if chunk.new_record? || chunk.content != content
        changed = true
        chunk_attributes.merge!(
          embedding: nil,
          embedding_provider: nil,
          embedding_model: nil,
          embedding_content_digest: nil
        )
      end
      chunk.update!(chunk_attributes)
    end
    knowledge_chunks.where.not(section: sections.keys).destroy_all
    update!(indexed_at: nil) if changed
  end

  def sections
    {
      "symptoms" => symptoms,
      "root-cause" => root_cause,
      "resolution" => resolution_steps.join("\n"),
      "verification" => verification
    }
  end

  private

  def resolution_steps_are_strings
    valid = resolution_steps.is_a?(Array) && resolution_steps.any? && resolution_steps.all? { |step| step.is_a?(String) && step.present? }
    errors.add(:resolution_steps, "must be a non-empty array of strings") unless valid
  end
end
