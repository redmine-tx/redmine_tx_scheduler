class AddCronSupportToSchedulerTaskStats < ActiveRecord::Migration[6.1]
  def up
    add_column :scheduler_task_stats, :cron_expression, :string, limit: 255 unless column_exists?(:scheduler_task_stats, :cron_expression)
    add_column :scheduler_task_stats, :schedule_type, :string, limit: 20, default: 'period', null: false unless column_exists?(:scheduler_task_stats, :schedule_type)

    add_index :scheduler_task_stats, :schedule_type unless index_exists?(:scheduler_task_stats, :schedule_type)
  end

  def down
    remove_index :scheduler_task_stats, :schedule_type if index_exists?(:scheduler_task_stats, :schedule_type)
    remove_column :scheduler_task_stats, :schedule_type if column_exists?(:scheduler_task_stats, :schedule_type)
    remove_column :scheduler_task_stats, :cron_expression if column_exists?(:scheduler_task_stats, :cron_expression)
  end
end
