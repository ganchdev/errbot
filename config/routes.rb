# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "bot/verify", to: "bot#verify"
    end
  end

  scope controller: :auth do
    get "/auth", action: :new
    get "/auth/:provider/callback", action: :callback
    match :logout, action: :destroy, via: [:delete, :get]
  end

  get "/auth/failure", to: redirect("/auth")

  get "bot_verify", to: "bot_verify#show"
  resources :authorized_users, only: [:index]

  root to: "dashboard#index"
end
