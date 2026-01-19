class SchedulerController < ApplicationController
  # 모든 인증과 권한 확인을 건너뛰기
  skip_before_action :session_expiration, :user_setup, :check_if_login_required, 
                     :set_localization, :check_password_change, :check_twofa_activation
  
  # API 액션들에 대해 API 인증 허용
  accept_api_auth :ping, :status, :execute_task
  
  # ping API - 외부 cron에서 호출
  def ping
    begin
      # 스케줄러가 비활성화되어 있으면 실행하지 않음
      if plugin_disabled?
        response_data = {
          success: false,
          message: 'Scheduler is disabled',
          timestamp: Time.current
        }
      else
        # 모든 등록된 작업 실행
        result = RedmineScheduler.execute_all_tasks
        
        response_data = {
          success: result[:success],
          message: result[:success] ? 'Tasks executed successfully' : result[:error],
          executed_at: result[:executed_at],
          total_tasks: result[:total_tasks] || 0,
          task_results: result[:task_results] || {},
          timestamp: Time.current
        }
      end
      
      respond_to do |format|
        format.json { render json: response_data, status: 200 }
        format.html { render plain: response_data.to_json, status: 200 }
        format.any { render plain: response_data.to_json, status: 200 }
      end
      
    rescue => e
      Rails.logger.error "Scheduler ping error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # 마이그레이션 에러인지 확인
      if e.message.include?('scheduler_task_stats') || e.message.include?('relation') || e.message.include?('table')
        error_data = {
          success: false,
          message: "Migration required: Please run 'bundle exec rake redmine:plugins:migrate NAME=redmine_tx_scheduler'",
          error_type: "migration_required",
          timestamp: Time.current
        }
      else
        error_data = {
          success: false,
          message: "Internal error: #{e.message}",
          error_type: "internal_error",
          timestamp: Time.current
        }
      end
      
      respond_to do |format|
        format.json { render json: error_data, status: 500 }
        format.html { render plain: error_data.to_json, status: 500 }
        format.any { render plain: error_data.to_json, status: 500 }
      end
    end
  end
  
  # 상태 조회 API
  def status
    begin
      tasks_info = RedmineScheduler.all_tasks_info
      
      response_data = {
        success: true,
        scheduler_enabled: !plugin_disabled?,
        total_tasks: RedmineScheduler.tasks_count,
        task_names: RedmineScheduler.task_names,
        tasks_info: tasks_info,
        timestamp: Time.current
      }
      
      respond_to do |format|
        format.json { render json: response_data, status: 200 }
        format.html { render plain: response_data.to_json, status: 200 }
        format.any { render plain: response_data.to_json, status: 200 }
      end
      
    rescue => e
      Rails.logger.error "Scheduler status error: #{e.message}"
      
      # 마이그레이션 에러인지 확인
      if e.message.include?('scheduler_task_stats') || e.message.include?('relation') || e.message.include?('table')
        error_data = {
          success: false,
          message: "Migration required: Please run 'bundle exec rake redmine:plugins:migrate NAME=redmine_tx_scheduler'",
          error_type: "migration_required",
          timestamp: Time.current
        }
      else
        error_data = {
          success: false,
          message: "Error getting status: #{e.message}",
          error_type: "internal_error",
          timestamp: Time.current
        }
      end
      
      respond_to do |format|
        format.json { render json: error_data, status: 500 }
        format.html { render plain: error_data.to_json, status: 500 }
        format.any { render plain: error_data.to_json, status: 500 }
      end
    end
  end
  
  # 특정 작업 실행 API (테스트/디버깅용)
  def execute_task
    task_name = params[:task_name]
    force = params[:force] == 'true' || params[:force] == true
    
    if task_name.blank?
      error_data = {
        success: false,
        message: 'Task name is required',
        timestamp: Time.current
      }
      
      respond_to do |format|
        format.json { render json: error_data, status: 400 }
        format.html { render plain: error_data.to_json, status: 400 }
        format.any { render plain: error_data.to_json, status: 400 }
      end
      return
    end
    
    begin
      result = RedmineScheduler.execute_task(task_name, force: force)
      
      response_data = {
        success: result[:success],
        message: result[:success] ? 'Task executed' : result[:error] || result[:reason],
        task_name: task_name,
        result: result,
        timestamp: Time.current
      }
      
      respond_to do |format|
        format.json { render json: response_data, status: 200 }
        format.html { render plain: response_data.to_json, status: 200 }
        format.any { render plain: response_data.to_json, status: 200 }
      end
      
    rescue => e
      Rails.logger.error "Task execution error: #{e.message}"
      
      # 마이그레이션 에러인지 확인
      if e.message.include?('scheduler_task_stats') || e.message.include?('relation') || e.message.include?('table')
        error_data = {
          success: false,
          message: "Migration required: Please run 'bundle exec rake redmine:plugins:migrate NAME=redmine_tx_scheduler'",
          error_type: "migration_required",
          task_name: task_name,
          timestamp: Time.current
        }
      else
        error_data = {
          success: false,
          message: "Error executing task: #{e.message}",
          error_type: "internal_error",
          task_name: task_name,
          timestamp: Time.current
        }
      end
      
      respond_to do |format|
        format.json { render json: error_data, status: 500 }
        format.html { render plain: error_data.to_json, status: 500 }
        format.any { render plain: error_data.to_json, status: 500 }
      end
    end
  end
  
  private
  
  def plugin_disabled?
    Setting.plugin_redmine_tx_scheduler['tx_scheduler_disabled'] == '1' || 
    Setting.plugin_redmine_tx_scheduler['tx_scheduler_disabled'] == true
  end
end
