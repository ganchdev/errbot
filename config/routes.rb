# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope controller: :auth do
    get "/auth", action: :new
    get "/auth/:provider/callback", action: :callback
    match :logout, action: :destroy, via: [:delete, :get]
  end

  get "/auth/failure", to: redirect("/auth")

  resources :authorized_users, only: [:index]

  root to: "dashboard#index"
end
