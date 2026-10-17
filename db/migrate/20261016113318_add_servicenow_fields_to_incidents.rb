class AddServicenowFieldsToIncidents < ActiveRecord::Migration[8.1]
  def change
    add_column :incidents, :number, :string
    add_column :incidents, :caller_id, :string
    add_column :incidents, :requested_by, :string
    add_column :incidents, :short_description, :string
    add_column :incidents, :description, :text
    add_column :incidents, :service_affected, :string
    add_column :incidents, :priority, :integer, default: 2
    add_column :incidents, :state, :integer, default: 0
    add_column :incidents, :sla_status, :integer, default: 0
    add_column :incidents, :category, :string, default: "Enterprise Software"
    add_column :incidents, :assignment_group, :string, default: "ITSM Platform Operations"
    add_column :incidents, :resolution_notes, :text
    add_column :incidents, :on_hold_reason, :string
    add_index :incidents, :number, unique: true
  end
end
