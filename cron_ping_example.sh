#!/bin/bash

# Redmine TX Scheduler - Cron Ping 스크립트
# 매 5분마다 실행하도록 crontab에 등록하세요
# 예: */5 * * * * /path/to/redmine/plugins/redmine_tx_scheduler/cron_ping_example.sh

# Redmine 서버 URL 설정
REDMINE_URL="http://localhost:3000"

# 로그 파일 경로
LOG_FILE="/tmp/redmine_scheduler_cron.log"

# 현재 시간
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting scheduler ping..." >> $LOG_FILE

# ping API 호출 (확장자 없이도 동작)
RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" "$REDMINE_URL/scheduler/ping")

# HTTP 응답 코드 추출
HTTP_CODE=$(echo "$RESPONSE" | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2)
JSON_RESPONSE=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')

echo "[$TIMESTAMP] HTTP Response Code: $HTTP_CODE" >> $LOG_FILE
echo "[$TIMESTAMP] Response: $JSON_RESPONSE" >> $LOG_FILE

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "[$TIMESTAMP] Scheduler ping successful" >> $LOG_FILE
else
    echo "[$TIMESTAMP] Scheduler ping failed with HTTP $HTTP_CODE" >> $LOG_FILE
fi

echo "[$TIMESTAMP] Ping completed" >> $LOG_FILE
echo "" >> $LOG_FILE

# 로그 파일 크기 제한 (1000라인 초과시 절반으로 축소)
LOG_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$LOG_LINES" -gt 1000 ]; then
    tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    echo "[$TIMESTAMP] Log file rotated" >> $LOG_FILE
fi
