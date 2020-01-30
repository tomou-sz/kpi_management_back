Rails.application.routes.draw do
  resources :users do
    get :sprint_tickets
  end
  resource :daily_work_logs do
    get :get_work_log
  end

  resource :productivities do
    get :sprint_productivity
  end

  resource :sprints do
    get :board_sprints
  end

  resource :reports do
    post :save_sprint_time_tracking
    get :total_sprint_time_tracking
  end
  root 'daily_work_logs#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
