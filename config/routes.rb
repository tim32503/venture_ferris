Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Public pages
  root "welcome#index"
  get "privacy", to: "welcome#privacy"
  get "error(/:error_code)", to: "welcome#error", as: :error_page

  # Player-facing game flow (session-based identity; see docs/REFACTOR_PLAN.md §2)
  namespace :game do
    # Entry: serial-number login (legacy /wheel/login + /wheel/register + /wheel/updateSNo)
    get "login", to: "sessions#new"
    post "session", to: "sessions#create"
    patch "session", to: "sessions#update"
    delete "session", to: "sessions#destroy"

    # Team naming + readiness polling
    get "team", to: "teams#show"
    patch "team", to: "teams#update"
    get "team/status", to: "teams#status", defaults: { format: :json }

    # Job (character class) selection
    get "job", to: "jobs#show"
    patch "job", to: "jobs#update"
    get "job/status", to: "jobs#status", defaults: { format: :json }

    # Main menu
    root "home#show"

    # Maps: map2 is a spatial drill-down of map1 (questions 5-9), not a progress stage
    get "map", to: "maps#index", as: :current_map
    get "maps/:id", to: "maps#show", as: :map, constraints: { id: /[123]/ }

    resources :questions, param: :number, only: [ :show ], constraints: { number: /\d{1,2}/ } do
      member do
        post :answer
        post :timer
        post :hints
        get :status, defaults: { format: :json }
      end
    end

    # One boss per question number (mon01..mon11)
    resources :bosses, param: :number, only: [ :show ], constraints: { number: /\d{1,2}/ } do
      member do
        post :attacks
        post :ready
        post :skill
        get :status, defaults: { format: :json }
      end
    end

    get "score", to: "scores#show"
    post "score", to: "scores#create"

    get "reward", to: "rewards#show"
    patch "reward/contact", to: "rewards#update_contact"
    post "reward/codes", to: "rewards#allocate_codes"

    get "record", to: "records#show"
  end

  # Back office (server-side auth; replaces the legacy frontend-only gate)
  namespace :admin do
    get "login", to: "sessions#new"
    post "session", to: "sessions#create"
    delete "session", to: "sessions#destroy"
    root "dashboard#show"
    resources :serial_codes, only: [ :index, :create ]
  end
end
