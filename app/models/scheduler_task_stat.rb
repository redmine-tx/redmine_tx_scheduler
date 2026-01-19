class SchedulerTaskStat < ApplicationRecord
  validates :task_name, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :execution_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :schedule_type, presence: true, inclusion: { in: %w[period cron] }
  
  # period 기반 스케줄의 경우 period_seconds 필수
  validates :period_seconds, presence: true, numericality: { greater_than: 0 }, if: -> { schedule_type == 'period' }
  
  # cron 기반 스케줄의 경우 cron_expression 필수
  validates :cron_expression, presence: true, length: { maximum: 255 }, if: -> { schedule_type == 'cron' }

  # scope :recently_executed는 각 작업별로 period가 다르므로 사용하지 않음
  scope :executed, -> { where.not(last_executed_at: nil) }
  scope :ordered_by_name, -> { order(:task_name) }
  scope :ordered_by_last_execution, -> { order(last_executed_at: :desc) }

  # 작업 실행 기록
  def record_execution!
    update!(
      last_executed_at: Time.now,
      execution_count: execution_count + 1
    )
  end

  # 최근 실행 여부 확인 (스케줄 타입에 따라 다르게 처리)
  def recently_executed?
    return false unless last_executed_at
    
    if schedule_type == 'cron'
      # cron의 경우 최소 30초는 지나야 함 (중복 실행 방지)
      Time.now - last_executed_at < 30.seconds
    else
      # period의 경우 기존 로직 사용
      Time.now - last_executed_at < period_seconds.seconds
    end
  end

  # 스케줄을 인간이 읽기 쉬운 형태로 변환
  def schedule_in_words
    if schedule_type == 'cron'
      return "Invalid cron" unless cron_expression.present?
      # CronParser를 사용하여 변환
      begin
        parser = RedmineScheduler::CronParser.new(cron_expression)
        parser.human_readable
      rescue => e
        Rails.logger.warn "Failed to parse cron expression '#{cron_expression}': #{e.message}"
        cron_expression
      end
    else
      period_in_words
    end
  end
  
  # period를 인간이 읽기 쉬운 형태로 변환 (하위 호환성)
  def period_in_words
    return "" unless period_seconds
    
    if period_seconds < 60
      "#{period_seconds}초"
    elsif period_seconds < 3600
      minutes = period_seconds / 60
      remainder = period_seconds % 60
      if remainder == 0
        "#{minutes}분"
      else
        "#{minutes}분 #{remainder}초"
      end
    else
      hours = period_seconds / 3600
      minutes = (period_seconds % 3600) / 60
      if minutes == 0
        "#{hours}시간"
      else
        "#{hours}시간 #{minutes}분"
      end
    end
  end

  # 다음 실행 가능 시간
  def next_executable_at
    if schedule_type == 'cron'
      return Time.now unless cron_expression
      begin
        parser = RedmineScheduler::CronParser.new(cron_expression)
        parser.next_run_time(last_executed_at || Time.now)
      rescue
        nil
      end
    else
      return Time.now unless last_executed_at && period_seconds
      last_executed_at + period_seconds.seconds
    end
  end

  # 다음 실행까지 남은 시간 (초)
  def seconds_until_next_execution
    return 0 unless last_executed_at
    remaining = next_executable_at - Time.now
    [remaining.to_i, 0].max
  end

  # 작업 통계 정보를 해시로 반환
  def to_info_hash
    info = {
      name: task_name,
      description: description,
      schedule_type: schedule_type,
      last_executed_at: last_executed_at,
      execution_count: execution_count,
      recently_executed: recently_executed?,
      next_executable_at: next_executable_at,
      seconds_until_next_execution: seconds_until_next_execution
    }
    
    if schedule_type == 'cron'
      info[:cron_expression] = cron_expression
      info[:cron_human_readable] = schedule_in_words
    else
      info[:period_seconds] = period_seconds
      info[:period_in_words] = period_in_words
    end
    
    info
  end

  # 특정 작업의 통계 조회 또는 생성
  def self.find_or_initialize_for_task(task_name, task_description = nil, period_seconds = nil, cron_expression = nil)
    stat = find_or_initialize_by(task_name: task_name.to_s)
    
    # 스케줄 타입 결정
    schedule_type = cron_expression ? 'cron' : 'period'
    
    if stat.new_record?
      stat.description = task_description if task_description
      stat.schedule_type = schedule_type
      
      if cron_expression
        stat.cron_expression = cron_expression
      else
        stat.period_seconds = period_seconds || 300
      end
    else
      # 기존 레코드 업데이트
      needs_save = false
      
      # 스케줄 타입이 변경된 경우
      if stat.schedule_type != schedule_type
        stat.schedule_type = schedule_type
        needs_save = true
      end
      
      # cron 표현식 업데이트
      if cron_expression && stat.cron_expression != cron_expression
        stat.cron_expression = cron_expression
        needs_save = true
      end
      
      # period 업데이트
      if period_seconds && stat.period_seconds != period_seconds
        stat.period_seconds = period_seconds
        needs_save = true
      end
      
      # description 업데이트
      if task_description && stat.description != task_description
        stat.description = task_description
        needs_save = true
      end
      
      stat.save! if needs_save && stat.persisted?
    end
    
    stat
  end

  # 모든 작업 통계를 정보 해시 배열로 반환
  def self.all_tasks_info
    all.map(&:to_info_hash)
  end

  # 총 실행 횟수
  def self.total_executions
    sum(:execution_count)
  end

  # 최근 실행된 작업 수 (각 작업의 period에 따라)
  def self.recently_executed_count
    count = 0
    all.each do |stat|
      count += 1 if stat.recently_executed?
    end
    count
  end

  # 마지막 실행 시간
  def self.last_execution_time
    maximum(:last_executed_at)
  end
end
