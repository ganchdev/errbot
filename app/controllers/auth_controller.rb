# frozen_string_literal: true

class AuthController < ApplicationController

  layout "auth"

  allow_unauthenticated_access only: [:new, :callback]
  rate_limit to: 10, within: 3.minutes, only: :new, with: :redirect_on_rate_limit

  before_action :redirect_if_authenticated, only: [:new, :callback]

  def new
  end

  def callback
    auth_data = request.env["omniauth.auth"]["info"]
    auth_user = AuthorizedUser.find_by(email_address: auth_data["email"])

    unless auth_user
      redirect_to auth_path, alert: "Not authorized. Please contact an administrator."
      return
    end

    begin
      user = find_or_create_user(auth_data, auth_user)
      start_new_session_for(user)
      redirect_to root_path
    rescue ActiveRecord::RecordInvalid
      redirect_to auth_path, alert: "Sign in failed. Please try again."
    rescue StandardError => e
      Rails.logger.error("OmniAuth callback error: #{e.message}")
      redirect_to auth_path, alert: "Authentication failed. Please try again."
    end
  end

  def destroy
    terminate_session
    redirect_to auth_path, notice: "Logged out successfully."
  end

  private

  def redirect_if_authenticated
    return unless authenticated?

    redirect_to root_path
  end

  def redirect_on_rate_limit
    redirect_to auth_path, alert: "Too many attempts. Please try again later."
  end

  def find_or_create_user(auth_data, auth_user)
    user = User.find_or_initialize_by(email_address: auth_data["email"]) do |u|
      u.name = auth_data["name"]
      u.first_name = auth_data["first_name"]
      u.last_name = auth_data["last_name"]
      u.image = auth_data["image"]
    end

    if user.new_record?
      user.save!
      auth_user.update(user: user)
    end

    user
  end

end
