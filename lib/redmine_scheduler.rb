module RedmineScheduler

  # Cron 표현식을 파싱하고 다음 실행 시간을 계산하는 클래스
  # rufus-scheduler 스타일의 cron 표현식을 지원합니다.
  # 형식: "분 시 일 월 요일" 또는 특별 표현식 (@hourly, @daily, @weekly, @monthly)
  class CronParser
    # 특별 표현식 매핑
    SPECIAL_EXPRESSIONS = {
      '@yearly' => '0 0 1 1 *',
      '@annually' => '0 0 1 1 *',
      '@monthly' => '0 0 1 * *',
      '@weekly' => '0 0 * * 0',
      '@daily' => '0 0 * * *',
      '@midnight' => '0 0 * * *',
      '@hourly' => '0 * * * *'
    }.freeze

    # 각 필드의 범위
    FIELD_RANGES = {
      minute: 0..59,
      hour: 0..23,
      day: 1..31,
      month: 1..12,
      weekday: 0..7  # 0과 7은 모두 일요일
    }.freeze

    # 요일 이름 매핑 (선택적)
    WEEKDAY_NAMES = {
      'sun' => 0, 'sunday' => 0,
      'mon' => 1, 'monday' => 1,
      'tue' => 2, 'tuesday' => 2,
      'wed' => 3, 'wednesday' => 3,
      'thu' => 4, 'thursday' => 4,
      'fri' => 5, 'friday' => 5,
      'sat' => 6, 'saturday' => 6
    }.freeze

    # 월 이름 매핑 (선택적)
    MONTH_NAMES = {
      'jan' => 1, 'january' => 1,
      'feb' => 2, 'february' => 2,
      'mar' => 3, 'march' => 3,
      'apr' => 4, 'april' => 4,
      'may' => 5,
      'jun' => 6, 'june' => 6,
      'jul' => 7, 'july' => 7,
      'aug' => 8, 'august' => 8,
      'sep' => 9, 'september' => 9,
      'oct' => 10, 'october' => 10,
      'nov' => 11, 'november' => 11,
      'dec' => 12, 'december' => 12
    }.freeze

    attr_reader :cron_expression, :minute, :hour, :day, :month, :weekday

    def initialize(cron_expression)
      @cron_expression = cron_expression.to_s.strip.downcase
      parse_expression
    end

    # cron 표현식이 유효한지 확인
    def valid?
      return false if @cron_expression.blank?
      
      begin
        parse_expression
        true
      rescue => e
        Rails.logger.warn "CronParser: Invalid cron expression '#{@cron_expression}': #{e.message}"
        false
      end
    end

    # 현재 시간을 기준으로 다음 실행 시간을 계산
    # tolerance_seconds: ping 간격의 오차를 고려한 허용 시간 (기본 30초)
    def next_run_time(from_time = Time.now, tolerance_seconds = 30)
      return nil unless valid?
      
      # 1분 단위로 반올림 (초는 무시) - 시스템 로컬 타임존 사용  
      minutes_since_epoch = from_time.to_i / 60
      base_time = Time.at(minutes_since_epoch * 60)
      
      # 최대 4주(28일) 후까지 검색 (무한루프 방지)
      max_time = base_time + 28.days
      current_time = base_time
      
      while current_time <= max_time
        if matches_time?(current_time)
          # 현재 시간이 from_time보다 미래이거나, tolerance를 벗어난 경우 반환
          # 단, from_time이 last_executed_at인 경우 (과거 시간)는 다음 실행 시간을 찾아야 함
          time_diff = (current_time - from_time).to_i
          
          if time_diff > tolerance_seconds
            return current_time
          end
        end
        current_time += 1.minute
      end
      
      nil # 적합한 시간을 찾지 못함
    end

    # 주어진 시간이 cron 표현식과 일치하는지 확인
    def matches_time?(time)
      return false unless valid?
      
      time_minute = time.min
      time_hour = time.hour
      time_day = time.day
      time_month = time.month
      time_weekday = time.wday

      # 각 필드가 일치하는지 확인
      matches_field?(@minute, time_minute) &&
        matches_field?(@hour, time_hour) &&
        matches_field?(@day, time_day) &&
        matches_field?(@month, time_month) &&
        matches_field?(@weekday, time_weekday)
    end

    # 사람이 읽기 쉬운 형태로 변환
    def human_readable
      return @cron_expression if SPECIAL_EXPRESSIONS.key?(@cron_expression)
      
      parts = []
      
      # 분
      if @minute == ['*']
        parts << "매분"
      elsif @minute.size == 1
        parts << "#{@minute.first}분"
      else
        parts << "#{@minute.join(',')}분"
      end
      
      # 시
      if @hour == ['*']
        parts << "매시간"
      elsif @hour.size == 1
        parts << "#{@hour.first}시"
      else
        parts << "#{@hour.join(',')}시"
      end
      
      # 일
      if @day != ['*']
        if @day.size == 1
          parts << "#{@day.first}일"
        else
          parts << "#{@day.join(',')}일"
        end
      end
      
      # 월
      if @month != ['*']
        if @month.size == 1
          parts << "#{@month.first}월"
        else
          parts << "#{@month.join(',')}월"
        end
      end
      
      # 요일
      if @weekday != ['*']
        weekday_names = @weekday.map { |w| %w[일 월 화 수 목 금 토][w.to_i % 7] }
        if weekday_names.size == 1
          parts << "#{weekday_names.first}요일"
        else
          parts << "#{weekday_names.join(',')}요일"
        end
      end
      
      parts.join(' ')
    end

    private

    def parse_expression
      # 특별 표현식 처리
      if SPECIAL_EXPRESSIONS.key?(@cron_expression)
        @cron_expression = SPECIAL_EXPRESSIONS[@cron_expression]
      end
      
      # 공백으로 분리
      fields = @cron_expression.split(/\s+/)
      raise "Invalid cron format: expected 5 fields, got #{fields.size}" unless fields.size == 5
      
      @minute = parse_field(fields[0], :minute)
      @hour = parse_field(fields[1], :hour)
      @day = parse_field(fields[2], :day)
      @month = parse_field(fields[3], :month)
      @weekday = parse_field(fields[4], :weekday)
      
      # 요일 7을 0으로 변환 (둘 다 일요일)
      @weekday = @weekday.map { |w| w == 7 ? 0 : w }
    end

    def parse_field(field, field_type)
      return ['*'] if field == '*'
      
      range = FIELD_RANGES[field_type]
      values = []
      
      # 콤마로 분리된 여러 값 처리
      field.split(',').each do |part|
        if part.include?('/')
          # step values (예: */5, 1-10/2)
          base, step = part.split('/')
          step = step.to_i
          raise "Invalid step value: #{step}" if step <= 0
          
          if base == '*'
            start_val = range.first
            end_val = range.last
          elsif base.include?('-')
            start_val, end_val = base.split('-').map(&:to_i)
          else
            start_val = end_val = base.to_i
          end
          
          (start_val..end_val).step(step) do |val|
            values << val if range.include?(val)
          end
          
        elsif part.include?('-')
          # range (예: 1-5)
          start_val, end_val = part.split('-').map { |v| parse_value(v, field_type) }
          raise "Invalid range: #{start_val}-#{end_val}" if start_val > end_val
          (start_val..end_val).each { |val| values << val }
          
        else
          # single value
          values << parse_value(part, field_type)
        end
      end
      
      values.uniq.sort
    end

    def parse_value(value, field_type)
      # 숫자인 경우
      if value.match?(/^\d+$/)
        val = value.to_i
        range = FIELD_RANGES[field_type]
        raise "Value #{val} out of range for #{field_type} (#{range})" unless range.include?(val)
        return val
      end
      
      # 이름 매핑 확인
      case field_type
      when :month
        return MONTH_NAMES[value.downcase] if MONTH_NAMES.key?(value.downcase)
      when :weekday
        return WEEKDAY_NAMES[value.downcase] if WEEKDAY_NAMES.key?(value.downcase)
      end
      
      raise "Invalid value for #{field_type}: #{value}"
    end

    def matches_field?(field_values, time_value)
      return true if field_values == ['*']
      field_values.include?(time_value)
    end
  end

  # 스케줄러 작업을 정의하는 클래스
  class ScheduledTask
    attr_reader :name, :description, :period_seconds, :cron_expression, :cron_parser, :task_block
    
    def initialize(name:, description: nil, period: nil, cron: nil, &block)
      @name = name
      @description = description || name
      @task_block = block
      
      # cron과 period 중 하나는 반드시 설정되어야 함
      if cron && period
        raise "Cannot specify both 'cron' and 'period' parameters"
      elsif cron
        @cron_expression = cron
        @cron_parser = CronParser.new(cron)
        unless @cron_parser.valid?
          raise "Invalid cron expression: #{cron}"
        end
        @period_seconds = nil
      elsif period
        @period_seconds = period.to_i
        @cron_expression = nil
        @cron_parser = nil
      else
        # 기본값: 5분 간격
        @period_seconds = 300
        @cron_expression = nil
        @cron_parser = nil
      end
    end
    
    def execute(force: false)
      # DB에서 통계 조회 또는 생성
      stat = SchedulerTaskStat.find_or_initialize_for_task(@name, @description, @period_seconds, @cron_expression)
      
      # 실행 가능 시간 체크 (강제 실행이 아닌 경우에만)
      unless force || should_execute?(stat)
        next_time = next_execution_time(stat.last_executed_at)
        remaining_seconds = next_time ? [(next_time - Time.now).to_i, 0].max : 0
        
        Rails.logger.info "RedmineScheduler: Task '#{@name}' should not execute yet, skipping (next execution in #{remaining_seconds}s)"
        return { 
          success: false, 
          reason: 'not_scheduled',
          next_executable_at: next_time,
          seconds_until_next_execution: remaining_seconds
        }
      end
      
      begin
        Rails.logger.info "RedmineScheduler: Starting task '#{@name}' at #{Time.now}"
        
        result = @task_block.call
        
        # DB에 실행 정보 저장
        stat.record_execution!
        
        Rails.logger.info "RedmineScheduler: Task '#{@name}' completed successfully at #{Time.now} (Count: #{stat.execution_count})"
        
        next_time = next_execution_time(stat.last_executed_at)
        { 
          success: true, 
          result: result, 
          executed_at: stat.last_executed_at, 
          execution_count: stat.execution_count,
          next_executable_at: next_time
        }
        
      rescue => e
        Rails.logger.error "RedmineScheduler: Task '#{@name}' failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        { success: false, error: e.message, executed_at: Time.now }
      end
    end
    
    def info
      stat = SchedulerTaskStat.find_or_initialize_for_task(@name, @description, @period_seconds, @cron_expression)
      info_hash = stat.to_info_hash
      
      # cron 관련 정보 추가
      if @cron_expression
        info_hash[:cron_expression] = @cron_expression
        info_hash[:cron_human_readable] = @cron_parser.human_readable
        info_hash[:schedule_type] = 'cron'
      else
        info_hash[:schedule_type] = 'period'
      end
      
      info_hash
    end
    
    # cron 또는 period 기반으로 실행 가능한지 확인
    def should_execute?(stat)
      current_time = Time.now
      
      if @cron_expression
        # cron 기반: 현재 시간 기준으로 30초 전후 범위에서 cron 시간과 매칭되는지 확인
        tolerance = 30.seconds
        
        # 현재 시간을 1분 단위로 내림하여 기준 시간 생성 - 시스템 로컬 타임존 사용
        minutes_since_epoch = current_time.to_i / 60
        base_minute = Time.at(minutes_since_epoch * 60)
        
        # 기준 분과 다음 분을 체크 (현재 시간이 58분 30초라면 58분과 59분 모두 체크)
        should_run = false
        [base_minute, base_minute + 1.minute].each do |check_time|
          if @cron_parser.matches_time?(check_time)
            # 해당 cron 시간과 현재 시간의 차이가 tolerance 내에 있는지 확인
            time_diff = (current_time - check_time).abs
            if time_diff <= tolerance
              should_run = true
              break
            end
          end
        end
        
        return false unless should_run
        
        # 마지막 실행 시간이 있다면 최소 30초는 지났는지 확인 (중복 실행 방지)
        if stat.last_executed_at
          time_diff = current_time - stat.last_executed_at
          return time_diff >= 30.seconds
        end
        
        true
      else
        # period 기반: 기존 로직 사용
        return true unless stat.last_executed_at
        current_time - stat.last_executed_at >= @period_seconds.seconds
      end
    end
    
    # 다음 실행 시간 계산
    def next_execution_time(last_executed_at = nil)
      if @cron_expression
        @cron_parser.next_run_time(last_executed_at || Time.now)
      else
        return Time.now unless last_executed_at
        last_executed_at + @period_seconds.seconds
      end
    end
    
    # 스케줄 타입 반환
    def schedule_type
      @cron_expression ? 'cron' : 'period'
    end
  end
  
  # 스케줄러 관리자 클래스
  class << self
    def tasks
      @tasks ||= {}
    end
    
    # 작업 등록
    def register_task(name:, description: nil, period: nil, cron: nil, &block)
      if Rails.application.initialized?
        Rails.logger.error "RedmineScheduler: Task registration only allowed during Rails initialization"
        return
      end
      
      # 기본값 설정
      if period.nil? && cron.nil?
        period = 300  # 기본 5분
      end
      
      tasks[name.to_s] = ScheduledTask.new(name: name.to_s, description: description, period: period, cron: cron, &block)
      
      if cron
        Rails.logger.info "RedmineScheduler: Task '#{name}' registered (cron: #{cron})"
      else
        Rails.logger.info "RedmineScheduler: Task '#{name}' registered (period: #{period}s)"
      end
    end
    
    # 특정 작업 실행
    def execute_task(task_name, force: false)
      task = tasks[task_name.to_s]
      return { success: false, error: 'Task not found' } unless task
      
      task.execute(force: force)
    end
    
    # 모든 작업 실행 (ping에서 호출)
    def execute_all_tasks
      return { success: false, error: 'No tasks registered' } if tasks.empty?
      
      results = {}
      tasks.each do |name, task|
        results[name] = task.execute
      end
      
      {
        success: true,
        executed_at: Time.now,
        task_results: results,
        total_tasks: tasks.size
      }
    end
    
    # 모든 작업 정보 조회 (등록된 작업 + DB 통계)
    def all_tasks_info
      registered_names = tasks.keys
      
      # 테이블이 존재하지 않으면 기본 정보만 반환
      unless table_exists?
        Rails.logger.warn "RedmineScheduler: scheduler_task_stats table does not exist, returning basic info"
        return registered_names.map do |name|
          task = tasks[name]
          info = {
            name: name,
            description: task.description,
            last_executed_at: nil,
            execution_count: 0,
            recently_executed: false,
            next_executable_at: task.next_execution_time,
            seconds_until_next_execution: 0
          }
          
          if task.cron_expression
            info[:schedule_type] = 'cron'
            info[:cron_expression] = task.cron_expression
            info[:cron_human_readable] = task.cron_parser.human_readable
          else
            info[:schedule_type] = 'period'
            info[:period_seconds] = task.period_seconds
            info[:period_in_words] = format_period_in_words(task.period_seconds)
          end
          
          info
        end
      end
      
      # 테이블이 존재하면 DB에서 통계 조회
      db_stats = SchedulerTaskStat.where(task_name: registered_names)
      
      registered_names.map do |name|
        task = tasks[name]
        stat = db_stats.find { |s| s.task_name == name }
        
        if stat
          stat.to_info_hash
        else
          # DB에 아직 기록이 없는 경우
          info = {
            name: name,
            description: task.description,
            last_executed_at: nil,
            execution_count: 0,
            recently_executed: false,
            next_executable_at: task.next_execution_time,
            seconds_until_next_execution: 0
          }
          
          if task.cron_expression
            info[:schedule_type] = 'cron'
            info[:cron_expression] = task.cron_expression
            info[:cron_human_readable] = task.cron_parser.human_readable
          else
            info[:schedule_type] = 'period'
            info[:period_seconds] = task.period_seconds
            info[:period_in_words] = format_period_in_words(task.period_seconds)
          end
          
          info
        end
      end
    end
    
    # 특정 작업 정보 조회
    def task_info(task_name)
      task = tasks[task_name.to_s]
      return nil unless task
      
      stat = SchedulerTaskStat.find_by(task_name: task_name.to_s)
      if stat
        stat.to_info_hash
      else
        {
          name: task_name.to_s,
          description: task.description,
          last_executed_at: nil,
          execution_count: 0,
          recently_executed: false
        }
      end
    end
    
    # 등록된 작업 수
    def tasks_count
      tasks.size
    end
    
    # 작업 목록 (이름만)
    def task_names
      tasks.keys
    end
    
    # 모든 작업 제거 (개발/테스트용)
    def clear_all_tasks
      @tasks = {}
      Rails.logger.info "RedmineScheduler: All tasks cleared"
    end
    
    # 테이블 존재 여부 확인
    def table_exists?
      ActiveRecord::Base.connection.table_exists?('scheduler_task_stats')
    rescue => e
      Rails.logger.warn "RedmineScheduler: Could not check table existence: #{e.message}"
      false
    end
    
    # 마이그레이션 필요 여부 확인
    def migration_required?
      !table_exists?
    end
    
    # period를 인간이 읽기 쉬운 형태로 변환 (헬퍼)
    def format_period_in_words(period_seconds)
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
  end
end