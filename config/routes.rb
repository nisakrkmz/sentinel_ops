Rails.application.routes.draw do
  root "incidents#index"

  resources :knowledge_articles, only: [ :index, :show ], param: :slug, path: "knowledge"

  resources :incidents, only: [ :index, :new, :create, :show ] do
    member do
      post :start_progress
      post :investigate      # Geriye dönük uyumluluk
      post :put_on_hold
      post :resolve
      post :check_sla
      post :suggest_resolution
      post :approve_kb_candidate
      post :reject_kb_candidate
    end
    collection do
      post :simulate
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
