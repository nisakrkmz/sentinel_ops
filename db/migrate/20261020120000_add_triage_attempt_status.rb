class AddTriageAttemptStatus < ActiveRecord::Migration[8.1]
  def change
    add_column :decisions, :status, :string, null: false, default: "completed"
    add_column :decisions, :error_code, :string
  end
end
