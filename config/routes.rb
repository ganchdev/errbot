# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  post "/api/:project_id/store", to: "api/v1/events#create_sentry_store"
  post "/api/:project_id/envelope", to: "api/v1/events#create_sentry_envelope"

  namespace :api do
    namespace :v1 do
      post "bot/verify", to: "bot#verify"
      post "events", to: "events#create"
    end
  end

  scope controller: :auth do
    get "/auth", action: :new
    get "/auth/:provider/callback", action: :callback
    match :logout, action: :destroy, via: [:delete, :get]
  end

  get "/auth/failure", to: redirect("/auth")

  get "bot/verify", to: "bot_verify#show", as: :bot_verify
  resources :authorized_users, only: [:index]

  root to: "dashboard#index"
end
