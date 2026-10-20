class Handoff < ApplicationRecord
  enum :status, { open: "open", accepted: "accepted", rejected: "rejected" }, validate: true

  belongs_to :incident
  belongs_to :from_actor, class_name: "Actor"
  belongs_to :resolved_by, class_name: "Actor", optional: true

  validates :reason_code, presence: true
  validates :status, presence: true
  validates :confidence, numericality: { in: 0.0..1.0 }, allow_nil: true
  validate :brief_must_be_an_object

  private

  def brief_must_be_an_object
    errors.add(:brief, "must be an object") unless brief.is_a?(Hash)
  end
end
