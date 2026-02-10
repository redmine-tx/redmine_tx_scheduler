class AddExecutionStatusToSchedulerTaskStats < ActiveRecord::Migration[5.2]
  def change
    add_column :scheduler_task_stats, :last_attempted_at, :datetime, null: true
    add_column :scheduler_task_stats, :last_status, :string, limit: 20, null: true
    add_column :scheduler_task_stats, :last_error, :text, null: true
  end
end
