class CreateSchedulerTaskStats < ActiveRecord::Migration[6.1]
  def up
    unless table_exists?(:scheduler_task_stats)
      create_table :scheduler_task_stats, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' do |t|
        t.string :task_name, null: false, limit: 255
        t.text :description
        t.integer :period_seconds, default: 300, null: false  # 기본 5분(300초)
        t.datetime :last_executed_at
        t.integer :execution_count, default: 0, null: false
        t.timestamps null: false
      end

      add_index :scheduler_task_stats, :task_name, unique: true unless index_exists?(:scheduler_task_stats, :task_name)
      add_index :scheduler_task_stats, :last_executed_at unless index_exists?(:scheduler_task_stats, :last_executed_at)
    end
  end

  def down
    if table_exists?(:scheduler_task_stats)
      remove_index :scheduler_task_stats, :last_executed_at if index_exists?(:scheduler_task_stats, :last_executed_at)
      remove_index :scheduler_task_stats, :task_name if index_exists?(:scheduler_task_stats, :task_name)
      drop_table :scheduler_task_stats
    end
  end
end
