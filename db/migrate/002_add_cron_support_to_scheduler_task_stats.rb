class AddCronSupportToSchedulerTaskStats < ActiveRecord::Migration[6.1]
  def change
    add_column :scheduler_task_stats, :cron_expression, :string, limit: 255
    add_column :scheduler_task_stats, :schedule_type, :string, limit: 20, default: 'period', null: false
    
    add_index :scheduler_task_stats, :schedule_type
  end
end
