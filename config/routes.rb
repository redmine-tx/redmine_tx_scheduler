# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# 스케줄러 API 라우팅
get '/scheduler/ping', to: 'scheduler#ping'
get '/scheduler/status', to: 'scheduler#status'
post '/scheduler/execute/:task_name', to: 'scheduler#execute_task'
