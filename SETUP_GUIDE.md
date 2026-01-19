# Redmine TX Scheduler 설정 가이드

## 개요

이 플러그인은 외부 cron을 통해 스케줄된 작업을 실행하는 ping API 기반 스케줄러입니다.

## 설정 방법

### 1. Redmine 서버 설정

1. 플러그인을 설치합니다.
2. **마이그레이션을 실행합니다** (중요!):
   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_tx_scheduler RAILS_ENV=production
   ```
3. Redmine을 재시작합니다.
4. 관리자 페이지에서 플러그인 설정을 확인합니다.

**⚠️ 중요**: 마이그레이션을 실행하지 않으면 설정 페이지에서 오류 메시지가 표시됩니다.

### 2. Cron 설정

다음과 같이 crontab에 스케줄러 ping을 설정합니다:

```bash
# crontab 편집
crontab -e

# 매 5분마다 스케줄러 ping 실행
*/5 * * * * /path/to/redmine/plugins/redmine_tx_scheduler/cron_ping_example.sh
```

또는 curl을 직접 사용:

```bash
# 매 5분마다 실행 (단순한 방법)
*/5 * * * * curl -s http://your-redmine-server.com/scheduler/ping > /dev/null 2>&1

# 또는 JSON 형식으로 요청
*/5 * * * * curl -s -H "Content-Type: application/json" http://your-redmine-server.com/scheduler/ping.json > /dev/null 2>&1
```

### 3. API 엔드포인트

- **ping**: `GET /scheduler/ping` 또는 `GET /scheduler/ping.json` - 모든 등록된 작업 실행
- **status**: `GET /scheduler/status` 또는 `GET /scheduler/status.json` - 스케줄러 상태 조회
- **execute**: `POST /scheduler/execute/:task_name` 또는 `POST /scheduler/execute/:task_name.json` - 특정 작업 실행

### 4. 작업 등록

`init.rb`에서 작업을 등록할 수 있습니다:

```ruby
RedmineScheduler.register_task(
  name: 'my_task',
  description: 'My custom task',
  period: 1800  # 30분 (1800초)
) do
  # 작업 로직
  Rails.logger.info "작업 실행됨"
  "작업 완료"
end
```

#### Period 설정

- `period`: 작업 실행 간격 (초 단위)
- 기본값: 300초 (5분)
- 예시:
  - `period: 60` → 1분
  - `period: 300` → 5분  
  - `period: 1800` → 30분
  - `period: 3600` → 1시간
  - `period: 86400` → 24시간

### 5. 로그 확인

- Redmine 로그: `log/production.log` (또는 해당 환경)
- Cron 로그: `/tmp/redmine_scheduler_cron.log` (스크립트 사용시)

### 6. 문제 해결

#### API 응답 확인

```bash
# 단순한 방법
curl -v http://your-redmine-server.com/scheduler/ping
curl -v http://your-redmine-server.com/scheduler/status

# 또는 JSON 형식으로
curl -v -H "Content-Type: application/json" http://your-redmine-server.com/scheduler/ping.json
curl -v -H "Content-Type: application/json" http://your-redmine-server.com/scheduler/status.json
```

#### 로그 확인

```bash
tail -f log/production.log | grep RedmineScheduler
tail -f /tmp/redmine_scheduler_cron.log
```

## 주의사항

- **멀티 인스턴스 안전**: 여러 서버 환경에서 안전하게 동작합니다
- **중복 실행 방지**: 각 작업의 period에 따라 중복 실행을 방지합니다  
- **Cron 주기**: 가장 짧은 period보다 작게 설정하는 것을 권장합니다
  - 예: 가장 짧은 작업이 5분이면 cron을 3-4분마다 실행
- **DB 저장**: 모든 통계는 데이터베이스에 저장되어 서버 재시작 시에도 유지됩니다
- **보안**: 스케줄러 API는 모든 인증을 우회합니다. 필요시 방화벽에서 접근을 제한하세요
- **인증 없음**: User 인증, 세션, CSRF 토큰 등 모든 보안 검사를 건너뜁니다
- HTML, JSON 등 모든 형태의 요청을 허용합니다

## 실행 주기 관리

### 작업별 독립적 주기
각 작업은 독립적인 실행 주기를 가집니다:

```ruby
# 1분마다 실행
RedmineScheduler.register_task(name: 'frequent_task', period: 60) { ... }

# 1시간마다 실행  
RedmineScheduler.register_task(name: 'hourly_task', period: 3600) { ... }

# 하루에 한 번 실행
RedmineScheduler.register_task(name: 'daily_task', period: 86400) { ... }
```

### Cron 최적화
- **잦은 호출**: 짧은 period 작업이 있다면 cron을 자주 실행
- **효율적 호출**: 모든 작업이 긴 period라면 cron 간격을 늘려도 됨
