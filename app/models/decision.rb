class Decision < ApplicationRecord
  enum :kind, {
    triage: "triage",
    route: "route",
    dedupe: "dedupe",
    major_candidate: "major_candidate",
    needs_human: "needs_human",
    resolution: "resolution",
    verify: "verify"
  }, validate: true

  belongs_to :incident
  belongs_to :actor, optional: true

  validates :kind, presence: true
  validates :provider, presence: true
  validates :output_json, presence: true
  validates :output_json, presence: true
  validates :confidence, numericality: { in: 0.0..1.0 }, allow_nil: true
  validates :latency_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :json_fields_have_expected_types

  private

  def json_fields_have_expected_types
    errors.add(:output_json, "must be an object") unless output_json.is_a?(Hash)
    errors.add(:sources, "must be an array") unless sources.is_a?(Array)
  end
end
