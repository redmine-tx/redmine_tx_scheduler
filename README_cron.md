# RedmineScheduler Cron 지원 기능

RedmineScheduler가 이제 rufus-scheduler 형식의 cron 표현식을 지원합니다!

## 주요 기능

### 1. Cron 표현식 지원
기존의 `period` 기반 스케줄링 외에 cron 표현식을 사용한 정교한 스케줄링이 가능합니다.

```ruby
# 기존 방식 (period 기반)
RedmineScheduler.register_task(
  name: 'periodic_task',
  description: '5분마다 실행',
  period: 300  # 300초 = 5분
) do
  # 작업 내용
end

# 새로운 방식 (cron 기반)
RedmineScheduler.register_task(
  name: 'cron_task',
  description: '매일 오전 9시 실행',
  cron: '0 9 * * *'
) do
  # 작업 내용
end
```

### 2. 지원하는 Cron 형식

#### 기본 형식
`분 시 일 월 요일` (5개 필드)

- **분**: 0-59
- **시**: 0-23  
- **일**: 1-31
- **월**: 1-12
- **요일**: 0-7 (0과 7은 모두 일요일)

#### 특별 표현식
- `@yearly` 또는 `@annually`: 매년 1월 1일 자정
- `@monthly`: 매월 1일 자정
- `@weekly`: 매주 일요일 자정
- `@daily` 또는 `@midnight`: 매일 자정
- `@hourly`: 매시간 정각

#### 고급 패턴
- `*`: 모든 값
- `*/n`: n 간격마다 (예: `*/5` = 5분마다)
- `a-b`: 범위 (예: `9-17` = 9시부터 17시까지)
- `a,b,c`: 여러 값 (예: `1,3,5` = 1일, 3일, 5일)
- `a-b/n`: 범위에서 n 간격마다 (예: `1-10/2` = 1,3,5,7,9)

### 3. 실제 사용 예시

```ruby
Rails.application.config.after_initialize do
  # 매시간 정각에 실행
  RedmineScheduler.register_task(
    name: 'hourly_maintenance',
    description: '시간별 유지보수',
    cron: '0 * * * *'
  ) do
    Rails.logger.info "시간별 유지보수 실행: #{Time.current}"
    # 유지보수 작업 수행
  end

  # 평일 오전 9시에 실행
  RedmineScheduler.register_task(
    name: 'daily_report',
    description: '일일 리포트 생성',
    cron: '0 9 * * 1-5'
  ) do
    Rails.logger.info "일일 리포트 생성: #{Time.current}"
    # 리포트 생성 로직
  end

  # 평일 업무시간(9-17시) 중 15분마다 실행
  RedmineScheduler.register_task(
    name: 'business_monitoring',
    description: '업무시간 모니터링',
    cron: '*/15 9-17 * * 1-5'
  ) do
    Rails.logger.info "업무시간 모니터링: #{Time.current}"
    # 모니터링 로직
  end

  # 매일 자정에 실행 (특별 표현식 사용)
  RedmineScheduler.register_task(
    name: 'daily_cleanup',
    description: '일일 정리 작업',
    cron: '@daily'
  ) do
    Rails.logger.info "일일 정리 작업: #{Time.current}"
    # 정리 작업 수행
  end
end
```

### 4. Ping 오차 허용

외부 cron이 매분 정확히 ping하지 않을 수 있음을 고려하여, 30초의 허용 오차를 두고 근사치로 실행됩니다.

- cron 표현식과 정확히 일치하지 않더라도 30초 내의 오차는 허용
- 중복 실행을 방지하기 위해 마지막 실행 후 최소 30초는 대기

### 5. 혼합 사용 가능

period 기반 작업과 cron 기반 작업을 동시에 사용할 수 있습니다:

```ruby
# Period 기반 작업 (5분마다)
RedmineScheduler.register_task(
  name: 'frequent_check',
  period: 300
) do
  # 빈번한 체크 작업
end

# Cron 기반 작업 (매일 자정)
RedmineScheduler.register_task(
  name: 'nightly_backup',
  cron: '0 0 * * *'
) do
  # 야간 백업 작업
end
```

### 6. 작업 정보 조회

등록된 작업들의 정보를 조회할 때 스케줄 타입과 관련 정보가 포함됩니다:

```ruby
RedmineScheduler.all_tasks_info
# => [
#   {
#     name: "hourly_task",
#     schedule_type: "cron",
#     cron_expression: "0 * * * *",
#     cron_human_readable: "0분 매시간",
#     next_executable_at: 2025-01-15 11:00:00,
#     ...
#   },
#   {
#     name: "periodic_task", 
#     schedule_type: "period",
#     period_seconds: 300,
#     period_in_words: "5분",
#     next_executable_at: 2025-01-15 10:35:00,
#     ...
#   }
# ]
```

### 7. 마이그레이션

새로운 기능을 사용하기 위해서는 데이터베이스 마이그레이션이 필요합니다:

```bash
# Redmine 루트 디렉토리에서 실행
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 8. 테스트

기능 테스트를 위한 스크립트가 제공됩니다:

```ruby
# Rails 콘솔에서 실행
load 'plugins/redmine_tx_scheduler/test_cron_functionality.rb'
```

## 주의사항

1. `period`와 `cron`을 동시에 지정할 수 없습니다.
2. 잘못된 cron 표현식은 작업 등록 시 오류를 발생시킵니다.
3. 외부 ping의 정확성에 따라 실행 시간에 약간의 오차가 있을 수 있습니다.
4. cron 기반 작업은 최소 30초 간격으로만 실행됩니다 (중복 실행 방지).

## 업그레이드 가이드

기존 period 기반 작업들은 그대로 동작하므로, 점진적으로 cron 표현식으로 마이그레이션할 수 있습니다.
