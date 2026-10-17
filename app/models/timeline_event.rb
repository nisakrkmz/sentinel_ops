class TimelineEvent < ApplicationRecord
  belongs_to :incident

  validates :event_type, presence: true
  validates :message, presence: true
end
