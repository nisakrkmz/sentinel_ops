class TimelineEvent < ApplicationRecord
  belongs_to :incident
  belongs_to :actor, optional: true

  before_validation :assign_default_actor

  validates :event_type, presence: true
  validates :message, presence: true

  private

  def assign_default_actor
    self.actor ||= Current.actor || incident&.opened_by_actor
  end
end
