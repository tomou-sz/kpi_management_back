Rails.application.routes.draw do
  resources :users
  resource :daily_work_logs do
    get :get_work_log
  end
  root 'daily_work_logs#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
