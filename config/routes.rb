Rails.application.routes.draw do
  root "incidents#index"

  resources :incidents, only: [ :index, :new, :create, :show ] do
    member do
      post :start_progress
      post :investigate      # Geriye dönük uyumluluk
      post :put_on_hold
      post :resolve
      post :check_sla
    end
    collection do
      post :simulate
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
