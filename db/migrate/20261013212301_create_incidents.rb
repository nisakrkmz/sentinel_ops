class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.string :title
      t.string :service_name
      t.integer :severity
      t.integer :status
      t.text :error_message
      t.text :stack_trace
      t.string :error_signature
      t.datetime :sla_deadline
      t.datetime :sla_breached_at
      t.datetime :investigating_at
      t.datetime :resolved_at
      t.text :root_cause_analysis
      t.text :resolution_steps
      t.string :assigned_to

      t.timestamps
    end
  end
end
