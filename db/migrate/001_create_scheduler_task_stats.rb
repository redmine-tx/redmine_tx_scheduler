class CreateSchedulerTaskStats < ActiveRecord::Migration[6.1]
  def change
    create_table :scheduler_task_stats, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci' do |t|
      t.string :task_name, null: false, limit: 255
      t.text :description
      t.integer :period_seconds, default: 300, null: false  # 기본 5분(300초)
      t.datetime :last_executed_at
      t.integer :execution_count, default: 0, null: false
      t.timestamps null: false
    end
    
    add_index :scheduler_task_stats, :task_name, unique: true
    add_index :scheduler_task_stats, :last_executed_at
  end
end
