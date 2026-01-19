class UpdateExistingSchedulerTaskStats < ActiveRecord::Migration[6.1]
  def up
    # 기존 레코드들의 schedule_type을 'period'로 설정
    execute "UPDATE scheduler_task_stats SET schedule_type = 'period' WHERE schedule_type IS NULL OR schedule_type = ''"
    
    # 새로운 cron 작업들을 위한 기본값 설정은 애플리케이션에서 처리
  end

  def down
    # rollback 시에는 특별한 작업 불필요
  end
end
