Redmine::Plugin.register :redmine_tx_scheduler do
  name 'Redmine Tx Scheduler plugin'
  author 'KiHyun Kang'
  description 'Redmine Tx Scheduler plugin'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  settings default: {
    'tx_scheduler_disabled' => false
  }, partial: 'settings/redmine_tx_scheduler_settings'
end

Rails.application.config.after_initialize do
  # RedmineScheduler 로드
  require_dependency File.expand_path('../lib/redmine_scheduler', __FILE__)

  # 테스트 작업 등록 (ping API를 통해 실행됨)
  
=begin
  # 기존 period 기반 작업
  RedmineScheduler.register_task(
    name: 'tx_test_job',
    description: 'Test job for scheduler (period based)',
    period: 300  # 5분 (300초)
  ) do
    Rails.logger.info "TX Test Job (period) executed at #{Time.current}"
    "Test job (period) completed successfully"
  end
  
  # 새로운 cron 기반 작업들
  RedmineScheduler.register_task(
    name: 'at test',
    description: '11시 06분',
    cron: '06 11 * * *'  # 매일 11시 06분
  ) do
    Rails.logger.info "11시 06분 테스트 작업 executed at #{Time.current}"
    "11시 06분 테스트 작업 completed"
  end
  
  # 매분 실행되는 디버그 작업 (테스트용)
  RedmineScheduler.register_task(
    name: 'debug_every_minute',
    description: '매분 디버그 작업',
    cron: '* * * * *'  # 매분
  ) do
    Rails.logger.info "디버그 작업 - 현재 시간: #{Time.current}"
    "디버그 작업 완료: #{Time.current}"
  end
  
  RedmineScheduler.register_task(
    name: 'daily_cleanup',
    description: 'Daily cleanup task',
    cron: '@daily'  # 매일 자정
  ) do
    Rails.logger.info "Daily cleanup executed at #{Time.current}"
    "Daily cleanup completed"
  end
  
  RedmineScheduler.register_task(
    name: 'business_hours_check',
    description: 'Business hours monitoring',
    cron: '*/15 9-17 * * 1-5'  # 평일 9-17시 15분마다
  ) do
    Rails.logger.info "Business hours check executed at #{Time.current}"
    "Business hours check completed"
  end
=end
    
end