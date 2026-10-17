class CreateTimelineEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :timeline_events do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :event_type
      t.text :message

      t.timestamps
    end
  end
end
