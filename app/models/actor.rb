class Actor < ApplicationRecord
  enum :kind, { human: "human", agent: "agent", system: "system" }

  has_many :opened_incidents, class_name: "Incident", foreign_key: :opened_by_actor_id, dependent: :restrict_with_error
  has_many :api_tokens, dependent: :destroy
  has_many :decisions, dependent: :restrict_with_error
  has_many :outgoing_handoffs, class_name: "Handoff", foreign_key: :from_actor_id, dependent: :restrict_with_error
  has_many :resolved_handoffs, class_name: "Handoff", foreign_key: :resolved_by_id, dependent: :nullify
  has_many :timeline_events, dependent: :restrict_with_error
  has_one :user, dependent: :restrict_with_error

  validates :kind, presence: true
  validates :name, presence: true
  validate :scopes_must_be_an_array

  def self.demo_ui_operator
    find_or_create_by!(kind: :human, name: "Demo UI Operator (unauthenticated)")
  end

  private

  def scopes_must_be_an_array
    errors.add(:scopes, "must be an array") unless scopes.is_a?(Array)
  end
end
