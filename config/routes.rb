Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/docs'
  mount Rswag::Api::Engine => '/docs'
  
  mount PgHero::Engine, at: "pghero"

  get '/projects', to: 'projects#index', as: 'projects'
  get '/projects/:ecosystem', to: 'projects#ecosystem', as: 'projects_ecosystem'
  get '/projects/:ecosystem/:name', to: 'projects#show', as: 'project'

  resources :papers, only: [:index, :show], constraints: { id: /.*/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root "projects#index"
end
