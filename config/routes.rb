Rails.application.routes.draw do
  root "incidents#index"

  namespace :api do
    namespace :v1 do
      resources :incidents, only: [ :index, :create, :show ] do
        member do
          post :comments, action: :create_comment
          post :claim
          post :resolve
          post :handoff
        end
      end
      get "kb/search", to: "knowledge#search"
      get "events", to: "events#index"
    end
  end

  get "/api/v1/openapi.json", to: "api/v1/discovery#openapi"
  get "/.well-known/agent-card.json", to: "api/v1/discovery#agent_card"
  get "/llms.txt", to: "api/v1/discovery#llms"
  post "/mcp", to: "mcp#handle"

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
