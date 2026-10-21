Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Web app metadata linked from the application layout.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Application Status
  get "/status", to: "application#status"

  # Defines the root path route ("/")
  root "application#index"
end
