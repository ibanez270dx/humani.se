Rails.application.routes.draw do
  constraints AdminHost do
    scope module: :admin, as: :admin do
      root "dashboard#show"
      get "sign-in", to: "sessions#new", as: :sign_in
      delete "sign-out", to: "sessions#destroy", as: :sign_out
      get "auth/google_oauth2/callback", to: "sessions#create"
      resources :administrators, only: %i[index create update]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Web app metadata linked from the application layout.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Application Status
  get "/status", to: "application#status"

  # Defines the root path route ("/")
  constraints ->(request){ !AdminHost.matches?(request) } do
    root "application#index"
  end
end
