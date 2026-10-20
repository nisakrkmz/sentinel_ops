class KnowledgeChunk < ApplicationRecord
  belongs_to :knowledge_article

  validates :chunk_id, :section, :content, presence: true
  validates :chunk_id, uniqueness: true
  validate :embedding_is_numeric_vector

  private

  def embedding_is_numeric_vector
    return if embedding.nil?

    valid = embedding.is_a?(Array) && embedding.any? && embedding.all? { |value| value.is_a?(Numeric) && value.finite? }
    errors.add(:embedding, "must be a finite numeric vector") unless valid
  end
end
